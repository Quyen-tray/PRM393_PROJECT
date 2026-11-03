package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.domain.AppUser;
import com.hrm.coffeeshop.domain.Employee;
import com.hrm.coffeeshop.repository.AppUserRepository;
import com.hrm.coffeeshop.repository.EmployeeRepository;
import org.springframework.stereotype.Component;

import java.util.*;

@Component
public class PersonLookup {
    private final EmployeeRepository employees;
    private final AppUserRepository users;

    public PersonLookup(EmployeeRepository employees, AppUserRepository users) {
        this.employees = employees;
        this.users = users;
    }

    public Optional<Employee> employee(Long employeeId) { return employees.findById(employeeId); }

    public Long userIdOf(Long employeeId) { return employees.findById(employeeId).map(Employee::getUserId).orElse(null); }

    public String nameOf(Long employeeId) {
        return employees.findById(employeeId).flatMap(e -> users.findById(e.getUserId())).map(AppUser::getDisplayName).orElse(null);
    }

    /** Resolves display names for a group of employees using one lookup per table. */
    public Map<Long, String> namesOf(Collection<Long> employeeIds) {
        if (employeeIds == null || employeeIds.isEmpty()) return Map.of();

        List<Employee> employeeRows = employees.findAllById(employeeIds);
        Set<Long> userIds = new HashSet<>();
        for (Employee employee : employeeRows) {
            if (employee.getUserId() != null) userIds.add(employee.getUserId());
        }

        Map<Long, AppUser> usersById = new HashMap<>();
        if (!userIds.isEmpty()) {
            for (AppUser user : users.findAllById(userIds)) {
                usersById.put(user.getUserId(), user);
            }
        }

        Map<Long, String> names = new HashMap<>();
        for (Employee employee : employeeRows) {
            AppUser user = usersById.get(employee.getUserId());
            if (user != null) names.put(employee.getEmployeeId(), user.getDisplayName());
        }
        return names;
    }

    public String nameOfUser(Long userId) { return users.findById(userId).map(AppUser::getDisplayName).orElse(null); }
}
