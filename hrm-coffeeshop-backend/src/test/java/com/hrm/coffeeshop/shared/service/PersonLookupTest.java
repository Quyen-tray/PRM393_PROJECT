package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.domain.AppUser;
import com.hrm.coffeeshop.domain.Employee;
import com.hrm.coffeeshop.repository.AppUserRepository;
import com.hrm.coffeeshop.repository.EmployeeRepository;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.anyIterable;
import static org.mockito.Mockito.*;

class PersonLookupTest {
    private final EmployeeRepository employees = mock(EmployeeRepository.class);
    private final AppUserRepository users = mock(AppUserRepository.class);
    private final PersonLookup lookup = new PersonLookup(employees, users);

    @Test
    void namesOfLoadsEmployeesAndUsersInBatches() {
        Employee first = employee(1L, 101L);
        Employee second = employee(2L, 102L);
        when(employees.findAllById(anyIterable())).thenReturn(List.of(first, second));
        when(users.findAllById(anyIterable())).thenReturn(List.of(
                user(101L, "Nguyen Van An"),
                user(102L, "Tran Thi Bich Ngoc")));

        Map<Long, String> names = lookup.namesOf(Set.of(1L, 2L));

        assertEquals(Map.of(1L, "Nguyen Van An", 2L, "Tran Thi Bich Ngoc"), names);
        verify(employees, times(1)).findAllById(anyIterable());
        verify(users, times(1)).findAllById(anyIterable());
    }

    @Test
    void namesOfSkipsRepositoryCallsForEmptyEmployeeSet() {
        assertEquals(Map.of(), lookup.namesOf(List.of()));

        verifyNoInteractions(employees, users);
    }

    private static Employee employee(Long employeeId, Long userId) {
        Employee employee = new Employee();
        employee.setEmployeeId(employeeId);
        employee.setUserId(userId);
        return employee;
    }

    private static AppUser user(Long userId, String displayName) {
        AppUser user = new AppUser();
        user.setUserId(userId);
        user.setDisplayName(displayName);
        return user;
    }
}
