package com.example.springbootbackend.service;

import org.quartz.Job;
import org.quartz.JobExecutionContext;
import org.quartz.JobExecutionException;
import org.springframework.stereotype.Service;

@Service
public class QuartzJobService implements Job {

    @Override
    public void execute(JobExecutionContext context) throws JobExecutionException {
        // Job logic goes here
        System.out.println("Executing Quartz Job...");
    }
}