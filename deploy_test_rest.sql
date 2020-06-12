/*
 * Copyright (c) 2020 Pavel Mitrofanov
 * MIT License
 * More details at https://github.com/nblxa/oracle-test-schemas
 *
 * Execute this script as the TEST_REST user.
 */

begin
  ords.delete_module(
    p_module_name => 'test_log'
  );
  ords.define_module(
    p_module_name => 'test_log'
  , p_base_path   => 'log/'
  );
  ords.define_template(
    p_module_name => 'test_log'
  , p_pattern     => '.'
  );
  ords.define_handler(
    p_module_name => 'test_log'
  , p_pattern     => '.'
  , p_method      => 'GET'
  , p_source_type => ords.source_type_collection_feed
  , p_source      => '
      SELECT t.*
      FROM test_admin.schema_log t
      ORDER BY t.log_id DESC
    '
  );
  ords.delete_module(
    p_module_name => 'test_schema'
  );
  ords.define_module(
    p_module_name => 'test_schema'
  , p_base_path   => 'schema/'
  );
  ords.define_template(
    p_module_name => 'test_schema'
  , p_pattern     => '.'
  );
  ords.define_handler(
    p_module_name   => 'test_schema'
  , p_pattern       => '.'
  , p_method        => 'POST'
  , p_mimes_allowed => 'application/json'
  , p_source_type   => ords.source_type_plsql
  , p_source        => '
      declare
        v_schema_name test_admin.test_schema.schema_name%type;
      begin
        test_admin.schema_mgmt.create_test_schema(
          in_drop_timeout_min => :timeout
        , in_password         => :password
        , out_schema_name     => v_schema_name
        );
        :forward_location := ''./'' || v_schema_name;
        :status_code := 201;
      end;
    '
  );
  ords.define_handler(
    p_module_name => 'test_schema'
  , p_pattern     => '.'
  , p_method      => 'GET'
  , p_source_type => ords.source_type_collection_feed
  , p_source      => '
      SELECT t.*
      FROM test_admin.test_schema t
      ORDER BY t.schema_id DESC
    '
  );
  ords.define_template(
    p_module_name => 'test_schema'
  , p_pattern     => ':name'
  );
  ords.define_handler(
    p_module_name => 'test_schema'
  , p_pattern     => ':name'
  , p_method      => 'GET'
  , p_source_type => ords.source_type_collection_item
  , p_source      => '
      SELECT t.*
      FROM test_admin.test_schema t
      WHERE t.schema_name = :name
      ORDER BY t.schema_id DESC
    '
  );
  ords.define_handler(
    p_module_name => 'test_schema'
  , p_pattern     => ':name'
  , p_method      => 'DELETE'
  , p_source_type => ords.source_type_plsql
  , p_source      => '
      declare
        v_dropped boolean;
      begin
        test_admin.schema_mgmt.drop_test_schema(
          in_schema_name => :name
        , out_dropped    => v_dropped
        );
        if not nvl(v_dropped, false) then
          :status_code := 404;
        end if;
      end;
    '
  );
  commit;
end;
/
