# HTTP Connection Customization

The command line tool supports using HTTP Basic and adding custom HTTP headers to requests to either the source data providers or to the destination SensorThings API. This can be done by using specific command line arguments to enable these options.

(At this time, none of the data providers require custom headers or HTTP Basic. These features may be necessary for write-access to your SensorThings API instance.)

## HTTP Basic

Use the `--user` command line option, specifying the username and password separated by a colon (`:`):

```
$ ruby transload put metadata \
    --provider campbell_scientific \
    --station_id 606830 \
    --cache datastore/weather \
    --destination $DESTINATION \
    --user 'username:password'
```

By wrapping the string in single quotes, only some special characters need to be escaped. All HTTP requests done for this step will apply these credentials. **Warning**: If `get metadata` has not been done, then `put metadata` *may* run that step and send the HTTP credentials to the data provider server as well.

## Custom Headers

*Work in Progress*

One or more custom HTTP headers can be added to requests, for servers that use headers for custom authorization.

```
ruby $SCRIPT put metadata \
    --provider campbell_scientific \
    --station_id 606830 \
    --cache datastore/weather \
    --destination $DESTINATION \
    --header "St-P-Access-Token: asdf"
```

Each header will be added to *all* requests sent for this run of the tool. That includes the methods of GET, PUT, POST, and so on.

Note: It is possible to add headers here that would conflict with the headers set in the library, causing requests to fail; avoid overriding `Content-Type`.
