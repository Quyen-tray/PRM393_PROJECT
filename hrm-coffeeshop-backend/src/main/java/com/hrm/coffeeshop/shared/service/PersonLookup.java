package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.domain.AppUser;
import com.hrm.coffeeshop.domain.Employee;
import com.hrm.coffeeshop.repository.AppUserRepository;
import com.hrm.coffeeshop.repository.EmployeeRepository;
import org.springframework.stereotype.Component;

import java.util.Optional;

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

    public String nameOfUser(Long userId) { return users.findById(userId).map(AppUser::getDisplayName).orElse(null); }
}
