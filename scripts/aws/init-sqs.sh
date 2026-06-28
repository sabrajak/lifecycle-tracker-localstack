#!/bin/bash

# =============================================================================
# Lifecycle Queue — single shared queue used by ALL apps for child/parent tracking
# =============================================================================
aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name lifecycle-tracking-queue

# =============================================================================
# Per-App Callback Queues — callback_sqs_example.py
# =============================================================================
aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-simple-callbacks-app

aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-filtered-callbacks-app

aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-real-world-callbacks-app

aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-parent-child-callbacks-app

aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-my-service

# =============================================================================
# Per-App Callback Queues — basic_sqs_example.py
# =============================================================================
aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-simple-track-log-example

aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-parent-child-tracking-example

aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-find-examples

aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-auto-tracking-example

# =============================================================================
# Per-App Callback Queues — advanced_example.py
# =============================================================================
aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-error-handling-app

aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-complex-workflow-app

aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-hierarchical-tracking-app

# =============================================================================
# Per-App Callback Queues — monitor_sqs_example.py / monitor_unified_example.py
# =============================================================================
aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-scenario-all-success-ex-app

aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-scenario-some-failure-ex-app

aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-scenario-large-app

# =============================================================================
# Per-App Callback Queues — demo showcase / distributed examples
# =============================================================================
aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-advanced-tracking-app

aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-parent-child-monitor-app

aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-producer-app

aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-parent-child-app

# Multi-app handler example — Cisco IQ apps (PIN, SWC, FBA)
aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-PIN

aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-SWC

aws --endpoint-url http://localhost:4566 \
  sqs create-queue \
    --queue-name callback-queue-FBA
