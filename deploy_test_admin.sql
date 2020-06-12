/*
 * Copyright (c) 2020 Pavel Mitrofanov
 * MIT License
 * More details at https://github.com/nblxa/oracle-test-schemas
 *
 * Execute this script as the ADMIN user.
 */

begin
  for r in (
    select t.username
    from all_users t
    where t.username in ('TEST_ADMIN', 'TEST_REST')
    or regexp_like(t.username, 'TEST_[1-9][0-9]*')
  )
  loop
    for s in (select t.sid, t.serial# from v$session t where t.username = r.username)
    loop
      execute immediate 'alter system kill session ''' || s.sid || ',' || s.serial# || '''';
    end loop;
  	execute immediate 'drop user ' || r.username || ' cascade';
  end loop;
end;
/

create user test_admin identified by &TEST_ADMIN_PASSWORD;
alter user test_admin account lock;

grant connect, resource, unlimited tablespace to test_admin with admin option;
grant create user, drop user, create job to test_admin;
grant select on v$session to test_admin;

alter session set current_schema = test_admin;

create table test_admin.test_schema (
  schema_id   number(20, 0) generated by default on null as identity primary key
, schema_name varchar2(30) generated always as (cast('TEST_' || schema_id as varchar2(30)))
, drop_ts     timestamp not null
);

create table test_admin.schema_log (
  log_id    number generated by default on null as identity primary key
, schema_id number(20, 0)
, username  varchar2(30) default user not null
, sql_text  varchar2(1000) not null
, start_ts  timestamp default systimestamp not null
, end_ts    timestamp
, sqlerrm   varchar2(1000)
);

create or replace package test_admin.schema_mgmt
authid definer
as

  procedure create_test_schema
  (
    in_drop_timeout_min in integer
  , in_password         in varchar2
  , out_schema_name     out test_admin.test_schema.schema_name%type
  );

  procedure drop_test_schema
  (
    in_schema_name in test_admin.test_schema.schema_name%type
  , out_dropped    out boolean
  );

end schema_mgmt;
/

create or replace package body test_admin.schema_mgmt
as

  procedure exec_ddl
  (
    in_schema_id in test_admin.test_schema.schema_id%type
  , in_sql       in test_admin.schema_log.sql_text%type
  );

  function assert_password
  (
    in_password in varchar2
  )
  return varchar2
  is
  begin
    if instr(in_password, '"') > 0 or instr(in_password, chr(13)) > 0 or instr(in_password, chr(10)) > 0 then
      raise_application_error(-20001, 'Password contains illegal characters: double quote, carriage return, or line feed!');
    end if;
    return in_password;
  end assert_password;

  procedure register_schema
  (
    in_drop_ts      in  test_admin.test_schema.drop_ts%type
  , out_schema_id   out test_admin.test_schema.schema_id%type
  , out_schema_name out test_admin.test_schema.schema_name%type
  )
  is
  begin
    insert into test_admin.test_schema t (
      t.drop_ts
    )
    values (
      in_drop_ts
    )
    returning
      t.schema_id
    , t.schema_name
    into
      out_schema_id
    , out_schema_name;
    commit;
  end register_schema;

  procedure create_test_schema
  (
    in_drop_timeout_min in integer
  , in_password         in varchar2
  , out_schema_name     out test_admin.test_schema.schema_name%type
  )
  is
    v_schema_id   test_admin.test_schema.schema_id%type;
    v_schema_name test_admin.test_schema.schema_name%type;
    v_drop_ts     test_admin.test_schema.drop_ts%type;
  begin
    if in_drop_timeout_min <= 0 or in_drop_timeout_min is null then
      raise_application_error(-20001, 'Expected a positive integer for in_drop_timeout_min, but got: '
        || nvl(to_char(in_drop_timeout_min, 'TM'), 'null'));
    end if;
    v_drop_ts := systimestamp + numtodsinterval(in_drop_timeout_min, 'minute');
    register_schema(v_drop_ts, v_schema_id, v_schema_name);
    exec_ddl(v_schema_id, 'create user ' || v_schema_name || ' identified by "' || assert_password(in_password) || '"');
    -- can be replaced by custom privileges:
    exec_ddl(v_schema_id, 'grant connect, resource, unlimited tablespace to ' || v_schema_name);
    --
    sys.dbms_scheduler.create_job(
      job_name   => 'test_admin.drop_' || v_schema_name
    , job_type   => 'plsql_block'
    , job_action => 'declare v boolean; begin test_admin.schema_mgmt.drop_test_schema(''' || v_schema_name || ''', v); end;'
    , start_date => v_drop_ts
    , enabled    => true
    , auto_drop  => true
    );
    out_schema_name := v_schema_name;
  end create_test_schema;

  procedure drop_test_schema
  (
    in_schema_name in test_admin.test_schema.schema_name%type
  , out_dropped    out boolean
  )
  is
    v_schema_id test_admin.test_schema.schema_id%type;
  begin
    begin
      select t.schema_id
      into v_schema_id
      from test_admin.test_schema t
      where t.schema_name = upper(in_schema_name);
    exception
      when no_data_found then
        out_dropped := false;
        return;
    end;
    for s in (select t.sid, t.serial# from v$session t where t.username = upper(in_schema_name))
    loop
      exec_ddl(v_schema_id, 'alter system kill session ''' || s.sid || ',' || s.serial# || '''');
    end loop;
    exec_ddl(v_schema_id, 'drop user ' || in_schema_name || ' cascade');
    out_dropped := true;
    delete from test_admin.test_schema t
    where t.schema_id = v_schema_id;
    commit;
  end drop_test_schema;

  function log_create
  (
    in_schema_id in test_admin.test_schema.schema_id%type
  , in_sql       in test_admin.schema_log.sql_text%type
  )
  return test_admin.schema_log.log_id%type
  is
    pragma autonomous_transaction;
    v_log_id test_admin.schema_log.log_id%type;
  begin
    insert into test_admin.schema_log t (
      t.schema_id
    , t.sql_text
    )
    values (
      in_schema_id
    , regexp_replace(in_sql, '(identified by )"([^"]*)"', '\1"..."')
    )
    returning t.log_id
    into      v_log_id;
    commit;
    return v_log_id;
  end log_create;

  procedure log_update
  (
    in_log_id  in test_admin.schema_log.log_id%type
  , in_sqlerrm in test_admin.schema_log.sqlerrm%type
  )
  is
    pragma autonomous_transaction;
  begin
    update test_admin.schema_log t
    set t.end_ts = systimestamp
      , t.sqlerrm = in_sqlerrm
    where t.log_id = in_log_id;
    commit;
  end log_update;

  procedure exec_ddl
  (
    in_schema_id in test_admin.test_schema.schema_id%type
  , in_sql       in test_admin.schema_log.sql_text%type
  )
  is
    v_log_id number;
  begin
    v_log_id := log_create(in_schema_id, in_sql);
    begin
      execute immediate in_sql;
    exception
      when others then
        log_update(v_log_id, sqlerrm);
        raise;
    end;
    log_update(v_log_id, null);
  end exec_ddl;

end schema_mgmt;
/

create user test_rest identified by &TEST_REST_PASSWORD;
grant connect to test_rest;

grant execute on test_admin.schema_mgmt to test_rest;

grant select on test_admin.schema_log to test_rest;
grant select on test_admin.test_schema to test_rest;

begin
  ords.enable_schema(
    p_enabled             => true
  , p_schema              => 'TEST_REST'
  , p_url_mapping_type    => 'BASE_PATH'
  , p_url_mapping_pattern => 'test'
  , p_auto_rest_auth      => true
  );
  commit;
end;
/
