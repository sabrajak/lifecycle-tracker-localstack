#!/bin/bash

aws --endpoint-url=http://localhost:4566 \
  dynamodb create-table \
    --table-name audit_job_trail \
    --attribute-definitions \
        AttributeName=track_id,AttributeType=S \
        AttributeName=track_timestamp,AttributeType=N \
        AttributeName=status_type,AttributeType=S \
        AttributeName=parent_id,AttributeType=S \
        AttributeName=reference_id,AttributeType=S \
        AttributeName=track_status,AttributeType=S \
        AttributeName=tenant_id,AttributeType=S \
    --key-schema \
        AttributeName=track_id,KeyType=HASH \
        AttributeName=track_timestamp,KeyType=RANGE \
    --local-secondary-indexes \
       "[{\"IndexName\": \"TrackIdStatusTypeLSI\",
       \"KeySchema\":[{\"AttributeName\":\"track_id\",\"KeyType\":\"HASH\"},
                     {\"AttributeName\":\"status_type\",\"KeyType\":\"RANGE\"}],
       \"Projection\":{\"ProjectionType\":\"ALL\"}},
       {\"IndexName\": \"TrackIdTrackStatusLSI\",
       \"KeySchema\":[{\"AttributeName\":\"track_id\",\"KeyType\":\"HASH\"},
                     {\"AttributeName\":\"track_status\",\"KeyType\":\"RANGE\"}],
       \"Projection\":{\"ProjectionType\":\"ALL\"}}]" \
    --global-secondary-indexes \
            "[
                {
                    \"IndexName\": \"ParentIdStatusTypeGSI\",
                    \"KeySchema\": [{\"AttributeName\":\"parent_id\",\"KeyType\":\"HASH\"},
                                    {\"AttributeName\":\"status_type\",\"KeyType\":\"RANGE\"}],
                    \"Projection\":{\"ProjectionType\":\"ALL\"},
                    \"ProvisionedThroughput\": {
                        \"ReadCapacityUnits\": 10,
                        \"WriteCapacityUnits\": 5
                    }
                },
                {
                    \"IndexName\": \"ReferenceIdStatusTypeGSI\",
                    \"KeySchema\": [{\"AttributeName\":\"reference_id\",\"KeyType\":\"HASH\"},
                                    {\"AttributeName\":\"status_type\",\"KeyType\":\"RANGE\"}],
                    \"Projection\":{\"ProjectionType\":\"ALL\"},
                    \"ProvisionedThroughput\": {
                        \"ReadCapacityUnits\": 10,
                        \"WriteCapacityUnits\": 5
                    }
                },
                {
                    \"IndexName\": \"ParentIdTrackStatusGSI\",
                    \"KeySchema\": [{\"AttributeName\":\"parent_id\",\"KeyType\":\"HASH\"},
                                    {\"AttributeName\":\"track_status\",\"KeyType\":\"RANGE\"}],
                    \"Projection\":{\"ProjectionType\":\"ALL\"},
                    \"ProvisionedThroughput\": {
                        \"ReadCapacityUnits\": 10,
                        \"WriteCapacityUnits\": 5
                    }
                },
                {
                    \"IndexName\": \"ReferenceIdTrackStatusGSI\",
                    \"KeySchema\": [{\"AttributeName\":\"reference_id\",\"KeyType\":\"HASH\"},
                                    {\"AttributeName\":\"track_status\",\"KeyType\":\"RANGE\"}],
                    \"Projection\":{\"ProjectionType\":\"ALL\"},
                    \"ProvisionedThroughput\": {
                        \"ReadCapacityUnits\": 10,
                        \"WriteCapacityUnits\": 5
                    }
                },
                {
                    \"IndexName\": \"TenantIdStatusTypeGSI\",
                    \"KeySchema\": [{\"AttributeName\":\"tenant_id\",\"KeyType\":\"HASH\"},
                                    {\"AttributeName\":\"status_type\",\"KeyType\":\"RANGE\"}],
                    \"Projection\":{\"ProjectionType\":\"ALL\"},
                    \"ProvisionedThroughput\": {
                        \"ReadCapacityUnits\": 10,
                        \"WriteCapacityUnits\": 5
                    }
                },
                {
                    \"IndexName\": \"TenantIdTrackStatusGSI\",
                    \"KeySchema\": [{\"AttributeName\":\"tenant_id\",\"KeyType\":\"HASH\"},
                                    {\"AttributeName\":\"track_status\",\"KeyType\":\"RANGE\"}],
                    \"Projection\":{\"ProjectionType\":\"ALL\"},
                    \"ProvisionedThroughput\": {
                        \"ReadCapacityUnits\": 10,
                        \"WriteCapacityUnits\": 5
                    }
                }
            ]" \
    --provisioned-throughput \
        ReadCapacityUnits=10,WriteCapacityUnits=5
