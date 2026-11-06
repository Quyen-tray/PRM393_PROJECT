package com.hrm.coffeeshop.it;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.hrm.coffeeshop.HrmApplication;
import com.hrm.coffeeshop.config.JwtService;
import com.hrm.coffeeshop.domain.ShiftAssignment;
import com.hrm.coffeeshop.repository.ShiftAssignmentRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.context.transaction.TestTransaction;
import org.springframework.transaction.annotation.Transactional;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@SpringBootTest(classes = HrmApplication.class, webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Transactional
class ManagerScheduleIT extends IntegrationTestBase {
    private static final LocalDate FROM = LocalDate.of(2042, 11, 3);
    private static final LocalDate TO = FROM.plusDays(6);

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper mapper;
    @Autowired JwtService jwt;
    @Autowired ShiftAssignmentRepository assignments;
    @LocalServerPort int port;

    private long managerId;
    private long employeeId;
    private long firstId;
    private long middleId;
    private long lastId;

    @BeforeEach
    void createAssignments() {
        managerId = userIdByEmail("baonvchaos@gmail.com");
        employeeId = employeeIdByCode("NV001");
        // Insert out of chronological order so the assertions also verify sorting.
        lastId = assignment(employeeIdByCode("NV002"), TO);
        middleId = assignment(employeeId, FROM.plusDays(3));
        firstId = assignment(employeeId, FROM);
        assignment(employeeId, FROM.minusDays(1));
        assignment(employeeId, TO.plusDays(1));
    }

    private long assignment(long employee, LocalDate date) {
        ShiftAssignment row = new ShiftAssignment();
        row.setEmployeeId(employee);
        row.setWorkShiftId(workShiftId("CA_SANG"));
        row.setWorkDate(date);
        row.setPlannedStartAt(date.atTime(8, 0).atZone(VN).toInstant());
        row.setPlannedEndAt(date.atTime(12, 0).atZone(VN).toInstant());
        row.setCreatedBy(managerId);
        return assignments.saveAndFlush(row).getShiftAssignmentId();
    }

    private MockHttpServletRequestBuilder request() {
        return request(FROM, TO);
    }

    private MockHttpServletRequestBuilder request(LocalDate from, LocalDate to) {
        return get("/api/v1/shift-assignments")
                .header("Authorization", "Bearer " + jwt.createAccessToken(managerId))
                .param("from", from.toString())
                .param("to", to.toString());
    }

    private JsonNode list(MockHttpServletRequestBuilder request) throws Exception {
        var response = mvc.perform(request).andExpect(status().isOk()).andReturn().getResponse();
        return mapper.readTree(response.getContentAsString()).path("data");
    }

    private List<Long> ids(JsonNode page) {
        List<Long> ids = new ArrayList<>();
        page.path("items").forEach(row -> ids.add(row.path("assignmentId").asLong()));
        return ids;
    }

    @ParameterizedTest
    @ValueSource(strings = {"asc", "desc"})
    void managerCanLoadAndPaginateTheWeekInEitherSortDirection(String direction) throws Exception {
        List<Long> expected = "asc".equals(direction)
                ? List.of(firstId, middleId, lastId) : List.of(lastId, middleId, firstId);
        JsonNode first = list(request().param("sort", "plannedStartAt," + direction)
                .param("page", "0").param("size", "2"));
        assertEquals(expected.subList(0, 2), ids(first));
        assertEquals(3, first.path("totalElements").asInt());
        assertEquals(2, first.path("totalPages").asInt());

        JsonNode second = list(request().param("sort", "plannedStartAt," + direction)
                .param("page", "1").param("size", "2"));
        assertEquals(expected.subList(2, 3), ids(second));
        assertEquals(1, second.path("page").asInt());
    }

    @Test
    void defaultSortShowsTheNewestShiftFirst() throws Exception {
        assertEquals(List.of(lastId, middleId, firstId), ids(list(request())));
    }

    @Test
    void employeeFilterKeepsTheDateRangeAndTotalCount() throws Exception {
        JsonNode page = list(request().param("employeeId", Long.toString(employeeId))
                .param("sort", "plannedStartAt,asc").param("page", "1").param("size", "1"));
        assertEquals(List.of(middleId), ids(page));
        assertEquals(2, page.path("totalElements").asInt());
        assertEquals(2, page.path("totalPages").asInt());
    }

    @Test
    void weekWithoutAssignmentsReturnsAnEmptyPage() throws Exception {
        JsonNode page = list(request(FROM.plusWeeks(2), TO.plusWeeks(2))
                .param("sort", "plannedStartAt,asc"));
        assertEquals(List.of(), ids(page));
        assertEquals(0, page.path("totalElements").asInt());
    }

    @Test
    void managerScreenRequestSucceedsOverHttp() throws Exception {
        // Release fixture write locks before the server reads through another connection.
        TestTransaction.flagForRollback();
        TestTransaction.end();
        var request = HttpRequest.newBuilder(URI.create("http://127.0.0.1:" + port
                        + "/api/v1/shift-assignments?from=2026-11-02&to=2026-11-08"
                        + "&page=0&size=20&sort=plannedStartAt,asc"))
                .header("Authorization", "Bearer " + jwt.createAccessToken(managerId))
                .timeout(Duration.ofSeconds(10)).GET().build();
        var response = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build()
                .send(request, HttpResponse.BodyHandlers.ofString());
        assertEquals(200, response.statusCode());
        JsonNode body = mapper.readTree(response.body());
        assertTrue(body.path("success").asBoolean());
        assertTrue(body.path("data").path("items").isArray());
        assertEquals(0, body.path("data").path("page").asInt());
        assertEquals(20, body.path("data").path("size").asInt());
    }
}
