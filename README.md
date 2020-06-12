## Summary

With this REST API you can quickly provision temporary test schemas in your Oracle Cloud Autonomous Database.
Use the integrated deployment script to deploy the API on your database.

The REST API will be exposed by your database itself using [Oracle REST Data Services](https://www.oracle.com/database/technologies/appdev/rest.html)
(ORDS). You may access it either manually or from your CI environment.

It works with ['Always Free'](https://www.oracle.com/cloud/free/) Oracle Cloud Autonomous Databases.

## API overview

\<host\> is your database hostname.

<table>
<thead>
<tr><th>URL</th><th>Method</th><th>Service</th></tr>
</thead>
<tbody>

<tr>
<td>
https://<i>&lt;host&gt;</i>/ords/test/schema/
</td>
<td>GET</td>
<td>Get a list of currently available schemas.</td>
</tr>

<tr>
<td>
https://<i>&lt;host&gt;</i>/ords/test/schema/
</td>
<td>POST</td>
<td>

Create a new test schema.
<br />The request body must contain a JSON document containing parameters:
* `timeout` - a timeout in minutes, after which the schema will be automatically cleaned-up
* `password` - the new schema's password.

</td>
</tr>

<tr>
<td>
https://<i>&lt;host&gt;</i>/ords/test/schema/TEST_100500
</td>
<td>DELETE</td>
<td>

Drop a test schema named `TEST_100500`.
<br />Only test schemas created by the API can be dropped using this service.

</td>
</tr>

<tr>
<td>
https://<i>&lt;host&gt;</i>/ords/test/log/
</td>
<td>GET</td>
<td>

Get a log of SQL statements performed by the API.
<br />Note that database passwords are hidden in the logged SQL statements.

</td>
</tr>

</tbody>
</table>

## Database Setup

An Oracle Cloud Autonomous Database (either Transaction Processing or Data Warehouse) is a pre-requisite.
These scripts may work with standalone Oracle Database installations, however additional configuration
may be necessary.

Two permanent database schemas are set up:
* `TEST_ADMIN` contains the code for creating and dropping test schemas,
* `TEST_REST` contains the REST API for accessing the code in `TEST_ADMIN`.

Temporary test schemas will be created with names `TEST_1`, `TEST_2`, `TEST_3`, and so on.

### Automated deployment

To deploy the REST API automatically, run [deploy_to_cloud.sh](deploy_to_cloud.sh)
```bash
./deploy_to_cloud.sh -p my-admin-pass \
                     -a my-test_admin-pass \
                     -r my-test_rest-pass \
                     my-db-host.adb.eu-frankfurt-1.oraclecloudapps.com
```

### Manual deployment

For a manual deployment, follow these steps:

1. To create the permanent schemas, connect to your Oracle Cloud Autonomous Database using
   [SQL Developer Web](https://docs.oracle.com/en/cloud/paas/autonomous-data-warehouse-cloud/user/sql-developer-web.html)
   as `ADMIN` and execute the script [deploy_test_admin.sql](deploy_test_admin.sql).

   You will be prompted for passwords for `TEST_ADMIN` and `TEST_REST`.
  
2. To create the REST API using ORDS, connect again, this time as the `TEST_REST` schema created in the previous step.
   To do so, replace the `/admin/` in your SQL Developer Web URL with `/test/` and enter the password you set
   in the previous step.
   
3. As `TEST_REST`, execute the script [deploy_test_rest.sql](deploy_test_rest.sql).

The above steps can also be performed using SQL Developer or any other database tool instead.
