/*
 * Copyright (c) 2020 Pavel Mitrofanov
 * MIT License
 * More details at https://github.com/nblxa/oracle-test-schemas
 *
 * Execute this script as the TEST_REST user.
 */

begin
  for r in (select t.name from user_ords_modules t)
  loop
    ords.delete_module(r.name);
  end loop;
  for r in (select t.name from user_ords_privileges t where t.created_by = user)
  loop
    ords.delete_privilege(r.name);
  end loop;
  for r in (select t.name from user_ords_clients t)
  loop
    oauth.delete_client(r.name);
  end loop;
  for r in (select t.name from user_ords_roles t where t.created_by = user)
  loop
    ords.delete_role(r.name);
  end loop;
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
  ords.create_role('ci');
  declare
    v_roles owa.vc_arr;
    v_patterns owa.vc_arr;
    v_modules owa.vc_arr;
  begin
    v_roles(1) := 'ci';
    v_modules(1) := 'test_log';
    ords.define_privilege(
      p_privilege_name => 'test.log.privilege'
    , p_roles          => v_roles
    , p_patterns       => v_patterns
    , p_modules        => v_modules
    , p_label          => 'Read logs'
    , p_description    => 'Allows accessing the DDL logs.'
    , p_comments       => null
    );
  end;
  ords.create_privilege_mapping(
    p_privilege_name => 'test.log.privilege'
  , p_pattern        => '/log/*');
  declare
    v_roles owa.vc_arr;
    v_patterns owa.vc_arr;
    v_modules owa.vc_arr;
  begin
    v_roles(1) := 'ci';
    v_modules(1) := 'test_schema';
    ords.define_privilege(
      p_privilege_name => 'test.schema.privilege'
    , p_roles          => v_roles
    , p_patterns       => v_patterns
    , p_modules        => v_modules
    , p_label          => 'Manage schemas'
    , p_description    => 'Allows creating and browsing test schemas.'
    , p_comments       => null
    );
  end;
  ords.create_privilege_mapping(
    p_privilege_name => 'test.schema.privilege'
  , p_pattern        => '/schema/*');
  oauth.create_client(
    p_name            => 'ci_application'
  , p_grant_type      => 'client_credentials'
  , p_owner           => 'CI Application'
  , p_description     => 'Client for automated access from CI.'
  , p_support_email   => 'example@example.com'
  , p_privilege_names => null
  , p_support_uri     => 'http://example.com/'
  );
  oauth.grant_client_role(
    p_client_name => 'ci_application'
  , p_role_name   => 'ci'
  );
  commit;
end;
/

select id, name, client_id, client_secret from user_ords_clients;
