package com.hrm.coffeeshop.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import java.time.Clock;

@Configuration
public class ClockConfig {
    /** Nguồn thời gian duy nhất của server (UTC). Thời gian client chỉ là tham khảo. */
    @Bean
    public Clock clock() { return Clock.systemUTC(); }
}
