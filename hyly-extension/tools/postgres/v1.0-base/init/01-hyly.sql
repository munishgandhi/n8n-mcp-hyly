-- Hyly Extension for n8n
-- Exported: 2025-08-30 22:34:52.369904-04

CREATE SCHEMA IF NOT EXISTS hyly;



CREATE TABLE hyly.execution_backtrace (
    execution_id integer NOT NULL,
    step_index integer NOT NULL,
    node_uuid uuid,
    node_name text NOT NULL,
    input_json jsonb,
    output_json jsonb,
    next_node_uuid uuid,
    next_node_name text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE hyly.execution_backtrace ADD CONSTRAINT execution_backtrace_pkey PRIMARY KEY (execution_id, step_index);

CREATE OR REPLACE FUNCTION hyly._resolve_exec_val(val jsonb, exec_arr jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  s text;
  i bigint;
  len int;
BEGIN
  IF jsonb_typeof(exec_arr) <> 'array' THEN
    RETURN val;
  END IF;

  LOOP
    IF jsonb_typeof(val) = 'string' THEN
      s := val #>> '{}';
      IF s ~ '^\d+$' THEN
        i := s::bigint;
        len := jsonb_array_length(exec_arr);
        IF i >= 0 AND i < len THEN
          val := exec_arr -> (i::int);
          CONTINUE;
        ELSE
          RETURN to_jsonb(s);
        END IF;
      END IF;
    END IF;
    EXIT;
  END LOOP;

  RETURN val;
END $function$
;
CREATE OR REPLACE FUNCTION hyly.build_execution_backtrace(p_execution_id integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
-- Rewritten: 2025-09-08 - Using proven algorithm from 10-workflow-trace.sh  
-- Version: 2.0.1-array-format
DECLARE
  exec_data    jsonb;
  run_data_idx int;
  run_data     jsonb;
  node_names   text[];
  node_name    text;
  node_details jsonb[] := ARRAY[]::jsonb[];
  node_info    jsonb;
  input_data   jsonb;
  output_data  jsonb;
  i            int;
  j            int;
  next_node    text;
BEGIN
  -- Log that we're starting
  RAISE NOTICE 'Building backtrace for execution_id=%', p_execution_id;
  
  -- Get execution data in compressed array format
  SELECT data::jsonb
  INTO   exec_data
  FROM   public.execution_data
  WHERE  "executionId" = p_execution_id;

  IF exec_data IS NULL THEN
    RAISE EXCEPTION 'No execution data for executionId=%', p_execution_id;
  END IF;

  -- Clear existing backtrace
  DELETE FROM hyly.execution_backtrace WHERE execution_id = p_execution_id;

  -- Find runData index in compressed array - matches 10-workflow-trace.sh
  run_data_idx := -1;
  FOR i IN 0..(jsonb_array_length(exec_data)-1) LOOP
    IF jsonb_typeof(exec_data -> i) = 'object' AND 
       (exec_data -> i) ? 'runData' THEN
      run_data_idx := ((exec_data -> i) ->> 'runData')::int;
      EXIT;
    END IF;
  END LOOP;
  
  IF run_data_idx = -1 THEN
    RAISE EXCEPTION 'No runData found in array for executionId=%', p_execution_id;
  END IF;
  
  run_data := exec_data -> run_data_idx;
  
  -- Get all node names
  SELECT array_agg(key ORDER BY key) INTO node_names FROM jsonb_object_keys(run_data) AS key;
  
  IF array_length(node_names, 1) = 0 THEN
    RAISE EXCEPTION 'No nodes found in runData for executionId=%', p_execution_id;
  END IF;

  -- Process each node using 10-workflow-trace.sh algorithm
  FOREACH node_name IN ARRAY node_names LOOP
    DECLARE
      node_ptr      text;
      node_exec_idx int;
      exec_data_obj jsonb;
      data_idx      int;
      node_data_obj jsonb;
      main_idx      int;
      main_data     jsonb;
      output_arr_idx int;
      output_array  jsonb;
      resolved_output jsonb[] := ARRAY[]::jsonb[];
      start_time    bigint;
      exec_time     int;
    BEGIN
      -- Get node pointer from runData
      node_ptr := run_data ->> node_name;
      
      IF node_ptr IS NOT NULL AND node_ptr ~ '^[0-9]+$' THEN
        node_exec_idx := node_ptr::int;
        
        -- Get node execution data array
        IF node_exec_idx < jsonb_array_length(exec_data) THEN
          node_info := exec_data -> node_exec_idx;
          
          IF jsonb_array_length(node_info) > 0 THEN
            exec_data_obj := exec_data -> (node_info ->> '0')::int;
            
            -- Extract timing info
            start_time := COALESCE((exec_data_obj ->> 'startTime')::bigint, 0);
            exec_time := COALESCE((exec_data_obj ->> 'executionTime')::int, 0);
            
            -- Get output data following the pointer chain
            IF exec_data_obj ? 'data' THEN
              data_idx := (exec_data_obj ->> 'data')::int;
              node_data_obj := exec_data -> data_idx;
              
              IF node_data_obj ? 'main' THEN
                main_idx := (node_data_obj ->> 'main')::int;
                main_data := exec_data -> main_idx;
                
                IF jsonb_array_length(main_data) > 0 THEN
                  output_arr_idx := (main_data ->> '0')::int;
                  output_array := exec_data -> output_arr_idx;
                  
                  -- Resolve each output item
                  FOR j IN 0..(jsonb_array_length(output_array)-1) LOOP
                    DECLARE
                      item_idx int;
                      item jsonb;
                    BEGIN
                      item_idx := (output_array ->> j)::int;
                      item := exec_data -> item_idx;
                      -- Apply reference resolution using existing function
                      resolved_output := resolved_output || hyly._resolve_exec_val(item, exec_data);
                    END;
                  END LOOP;
                END IF;
              END IF;
            END IF;
            
            -- Store node details
            node_details := node_details || jsonb_build_object(
              'nodeName', node_name,
              'output', CASE WHEN array_length(resolved_output, 1) > 0 
                           THEN array_to_json(resolved_output)::jsonb 
                           ELSE NULL END,
              'startTime', start_time,
              'executionTime', exec_time,
              'executionStatus', COALESCE(exec_data_obj ->> 'executionStatus', 'success')
            );
          END IF;
        END IF;
      END IF;
    END;
  END LOOP;

  -- Sort node details by execution order (startTime)
  SELECT array_agg(node_detail ORDER BY (node_detail ->> 'startTime')::bigint)
  INTO node_details
  FROM unnest(node_details) AS node_detail
  WHERE (node_detail ->> 'startTime')::bigint > 0;

  -- Insert backtrace records in execution order
  FOR i IN 1..array_length(node_details, 1) LOOP
    node_info := node_details[i];
    
    -- Determine next node name
    next_node := NULL;
    IF i < array_length(node_details, 1) THEN
      next_node := node_details[i+1] ->> 'nodeName';
    END IF;
    
    -- Find node UUID from workflow data if available
    DECLARE
      wf_data jsonb;
      nodes jsonb;
      node jsonb;
      node_uuid uuid := NULL;
      next_uuid uuid := NULL;
    BEGIN
      SELECT "workflowData"::jsonb INTO wf_data
      FROM public.execution_data 
      WHERE "executionId" = p_execution_id;
      
      IF wf_data IS NOT NULL THEN
        nodes := wf_data -> 'nodes';
        FOR node IN SELECT * FROM jsonb_array_elements(nodes) LOOP
          IF node ->> 'name' = node_info ->> 'nodeName' THEN
            BEGIN
              node_uuid := (node ->> 'id')::uuid;
            EXCEPTION WHEN others THEN
              node_uuid := NULL;
            END;
          END IF;
          
          IF next_node IS NOT NULL AND node ->> 'name' = next_node THEN
            BEGIN
              next_uuid := (node ->> 'id')::uuid;
            EXCEPTION WHEN others THEN
              next_uuid := NULL;
            END;
          END IF;
        END LOOP;
      END IF;
    END;

    INSERT INTO hyly.execution_backtrace (
      execution_id, step_index, node_uuid, node_name,
      input_json, output_json, next_node_uuid, next_node_name
    )
    VALUES (
      p_execution_id,
      i - 1,
      node_uuid,
      node_info ->> 'nodeName',
      '{}'::jsonb, -- Input will be added in future iteration
      node_info -> 'output',
      next_uuid,
      next_node
    );
  END LOOP;
  
  -- Log completion
  RAISE NOTICE 'Backtrace complete: % steps', array_length(node_details, 1);
END $function$
;

-- =============================================================================
-- AUTO-BACKTRACE TRIGGER FOR DEBUG WORKFLOWS
-- =============================================================================

CREATE OR REPLACE FUNCTION hyly.trigger_auto_backtrace()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  has_debug_tag boolean := false;
BEGIN
  -- Check if workflow has 'debug' tag via workflows_tags and tag_entity tables
  SELECT EXISTS (
    SELECT 1 
    FROM public.workflows_tags wt
    INNER JOIN public.tag_entity te ON te.id = wt."tagId"
    WHERE wt."workflowId" = NEW."workflowId"
    AND te.name = 'debug'
  ) INTO has_debug_tag;
  
  -- Only run backtrace for workflows with 'debug' tag
  IF has_debug_tag THEN
    RAISE NOTICE 'Auto-backtrace triggered for debug workflow execution_id=%', NEW.id;
    PERFORM hyly.build_execution_backtrace(NEW.id);
  ELSE
    RAISE DEBUG 'Skipping backtrace for non-debug workflow execution_id=%', NEW.id;
  END IF;
  
  RETURN NEW;
END $function$
;

-- Drop the old trigger on execution_data
DROP TRIGGER IF EXISTS execution_data_auto_backtrace ON public.execution_data;

-- Create trigger on execution_entity UPDATE when execution finishes
CREATE TRIGGER execution_entity_auto_backtrace
  AFTER UPDATE ON public.execution_entity
  FOR EACH ROW
  WHEN (OLD.finished = false AND NEW.finished = true)
  EXECUTE FUNCTION hyly.trigger_auto_backtrace();

-- Add comment for documentation
COMMENT ON TRIGGER execution_entity_auto_backtrace ON public.execution_entity IS 
'Automatically generates execution backtrace for workflows tagged with "debug" when execution finishes';

COMMENT ON FUNCTION hyly.trigger_auto_backtrace() IS 
'Trigger function that builds execution backtrace only for workflows with debug tag';

-- Create temporary table for API-based execution results
CREATE TABLE IF NOT EXISTS hyly.temp_execution_results (
  execution_id integer PRIMARY KEY,
  execution_json jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

COMMENT ON TABLE hyly.temp_execution_results IS 
'Temporary storage for execution data from n8n API endpoint calls';

-- v5.0.0 - API-based execution backtrace using n8n container HTTP endpoint
CREATE OR REPLACE FUNCTION hyly.build_execution_backtrace_api(p_execution_id integer)
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
  execution_data jsonb;
  data_flow jsonb;
  flow_step jsonb;
  node_count int := 0;
BEGIN
  -- Clear existing backtrace for this execution
  DELETE FROM hyly.execution_backtrace WHERE execution_id = p_execution_id;

  -- Check if external process has populated results
  IF EXISTS (SELECT 1 FROM hyly.temp_execution_results WHERE execution_id = p_execution_id) THEN
    -- Use results from external process
    SELECT execution_json INTO execution_data
    FROM hyly.temp_execution_results
    WHERE execution_id = p_execution_id;
    
    -- Clean up temp results
    DELETE FROM hyly.temp_execution_results WHERE execution_id = p_execution_id;
    
    -- Process execution data
    data_flow := execution_data -> 'data_flow';
    
    IF data_flow IS NOT NULL THEN
      -- Insert backtrace records for each step
      FOR flow_step IN SELECT * FROM jsonb_array_elements(data_flow) LOOP
        node_count := node_count + 1;
        
        INSERT INTO hyly.execution_backtrace (
          execution_id, step_index, node_uuid, node_name,
          input_json, output_json, next_node_uuid, next_node_name
        )
        VALUES (
          p_execution_id,
          (flow_step ->> 'step')::int - 1, -- Convert to 0-based index
          NULL, -- UUID resolution would require additional workflow data
          flow_step ->> 'node_name',
          flow_step -> 'input',
          flow_step -> 'output',
          NULL, -- UUID for next node would require additional workflow data
          CASE WHEN flow_step ->> 'goes_to' = 'END (final workflow output)' 
               THEN NULL 
               ELSE flow_step ->> 'goes_to' END
        );
      END LOOP;
      
      RAISE NOTICE 'Generated API-based backtrace for execution_id=% with % nodes', p_execution_id, node_count;
    ELSE
      RAISE NOTICE 'No data_flow found in execution data for execution_id=%', p_execution_id;
    END IF;
  ELSE
    -- Create a placeholder indicating external processing is needed
    INSERT INTO hyly.execution_backtrace (
      execution_id, step_index, node_uuid, node_name,
      input_json, output_json, next_node_uuid, next_node_name
    )
    VALUES (
      p_execution_id,
      0,
      NULL,
      'EXTERNAL_PROCESSING_REQUIRED',
      jsonb_build_object('message', 'Call external API to process this execution'),
      jsonb_build_object('endpoint', 'http://172.23.0.9:3001/execution/' || p_execution_id),
      NULL,
      NULL
    );
    
    RAISE NOTICE 'External processing required for execution_id=%. Call: curl http://172.23.0.9:3001/execution/%', p_execution_id, p_execution_id;
  END IF;
END $function$;
