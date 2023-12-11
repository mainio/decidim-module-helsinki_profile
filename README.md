# Decidim::HelsinkiProfile

A [Decidim](https://github.com/decidim/decidim) module to add
[Helsinki profile](https://github.com/City-of-Helsinki/open-city-profile)
authentication to Decidim as a way to authenticate and authorize the users.

The Helsinki profile is the City of Helsinki's way to manage user data in a
centralized way across all the digital city services. It allows the Helsinki
residents to login to different city services with a single profile and manage
their data in one place. It works through OpenID connect that handles the user
authentication flows.

The gem has been developed by [Mainio Tech](https://www.mainiotech.fi/).

The development has been sponsored by the
[City of Helsinki](https://www.hel.fi/).

## Installation

Add this line to your application's Gemfile:

```ruby
gem "decidim-helsinki_profile", github: "mainio/decidim-module-helsinki_profile", branck: "main"
```

And then execute:

```bash
$ bundle
```

After installation, add the following to `config/secrets.yml` and configure the
environment variables accordingly:

```yml
default: &default
  # ...
  omniauth:
    # ...
    helsinki:
      enabled: true
      auth_uri: <%= ENV["HELSINKIPROFILE_AUTH_URI"] %>
      auth_client_id: <%= ENV["HELSINKIPROFILE_AUTH_CLIENT_ID"] %>
      auth_client_secret: <%= ENV["HELSINKIPROFILE_AUTH_CLIENT_SECRET"] %>
      gdpr_client_id: <%= ENV["HELSINKIPROFILE_GDPR_CLIENT_ID"] %>
      profile_api_uri: <%= ENV["HELSINKIPROFILE_PROFILE_API_URI"] %>
      profile_api_client_id: <%= ENV["HELSINKIPROFILE_PROFILE_API_CLIENT_ID"] %>
      icon: account-login
```

Explanations for the configuration values:

- `HELSINKIPROFILE_AUTH_URI`: The authentication server (Keycloak) URI.
- `HELSINKIPROFILE_AUTH_CLIENT_ID`: The OIDC authentication client ID.
- `HELSINKIPROFILE_AUTH_CLIENT_SECRET`: The OIDC authentication client secret.
- `HELSINKIPROFILE_GDPR_CLIENT_ID`: The Helsinki profile GDPR client ID which is
  used to validate the requests to the GDPR API endpoints provided by this
  module (the GDPR client which is connecting to the GDPR API endpoints).
- `HELSINKIPROFILE_PROFILE_API_URI`: The full URI to the Helsinki profile's
  GraphQL API which provides verified further details about the user.
- `HELSINKIPROFILE_PROFILE_API_CLIENT_ID`: The client ID which is used to
  connect to the Helsinki profile's GraphQL API.

If you have overridden the `omniauth` configuration block for the environment
specific secrets and would like to enable Helsinki profile there too, you need
to repeat this same configuration for all environments.

Note that the `enabled` flag needs to be set to `true` through the secrets
because otherwise the module interprets that it has not been configured.

The example configuration will set the `account-login` icon for the the
authentication button from the Decidim's own iconset. In case you want to have a
better and more formal styling for the sign in button, you will need to
customize the sign in / sign up views.

## Usage

This gem adds the following to Decidim:

1. Helsinki profile OmniAuth provider in order to sign in with Helsinki profile
   through the Keycloak identity service.
2. Helsinki profile authorization in order to authorize users using the
   Helsinki profile user data (fetched through the Helsinki profile GraphQL
   API).
3. Helsinki profile GDPR API endpoints that allows the centralized Helsinki
   profile application to do programmatic GDPR requests to Decidim (e.g.
   download your data or delete the profile).

To enable the OmniAuth flow or the Helsinki profile authorization, you need to
sign in to the Decidim system management panel. After enabled from there, you
can start using them.

Using the Helsinki profile OmniAuth sign in method will automatically authorize
the users during their sign ins. This way they do not have to separately sign in
and authorize themselves using the same identity provider.

### Using with local identity service

Once the gem is installed, you can test it using local identity services to
ensure everything is working fine before starting the actual integration to the
testing/staging/production environments. Note that Helsinki profile will not be
configured for the localhost domain because Helsinki profile cannot call these
URIs externally for the GDPR endpoints. Therefore, it needs to be tested locally
before starting the actual integration process.

For running locally, you will need to setup the following:

1. PostgreSQL database and database user for Keycloak to connect and manage its
   database. This should be straight forward as Decidim also uses PostgreSQL, so
   all you need to do is to setup a new database and add a Keycloak database
   user with the permissions to manage that database.
2. Keycloak development server using the
  [installation instructions](https://www.keycloak.org/getting-started/getting-started-zip)
  from the Keycloak documentation.
3. A configured `helsinki-tunnistus` realm for the Keycloak server once you have
   it up and running. You can find an example configuration from the
   [./examples/helsinki-tunnistus-realm.json](examples of this repo) that you
   can import to Keycloak to start utilizing it.
4. A configured client at the Keycloak server for Decidim. The example contains
   a client named `decidim_dev` that you can use to test the authentication
   flow (please copy the secret from the Keycloak UI for the client).
5. A user added to the Keycloak server within the `helsinki-tunnistus` realm
   that can be utilized to test the login process.

Once all this is configured and running, add the following configurations to
your local `.rbenv-vars` file (assuming you are using rbenv):

```
HELSINKIPROFILE_AUTH_URI=http://localhost:8080/realms/helsinki-tunnistus
HELSINKIPROFILE_AUTH_CLIENT_ID=decidim_dev
HELSINKIPROFILE_AUTH_CLIENT_SECRET=<copy secret from Keycloak>
# Note that the GDPR client ID will become relevant at the next stage when we
# will test the GDPR API provided by this module.
HELSINKIPROFILE_GDPR_CLIENT_ID=exampleapi
# Note that the profile API is not relevant to test the normal OIDC
# authentication flow with limited authorization details. The user will be
# authorized with the details provided by the OIDC user info instead in case
# the profile API cannot be connected to.
HELSINKIPROFILE_PROFILE_API_URI=http://localhost:8000/graphql/
HELSINKIPROFILE_PROFILE_API_CLIENT_ID=profile-api-dev
```

After this configuration, restart the Decidim server, enable the Helsinki
profile authentication and test authenticating through Helsinki profile while
you have the Keycloak server up and running. You should be now able to login to
Decidim using Keycloak.

After this is tested, you can test the GDPR API endpoints using the
[Helsinki profile GDPR API Tester](https://github.com/City-of-Helsinki/profile-gdpr-api-tester).
Set this tool up following the insallation instructions and use the following
`.env` configuration file to connect to Decidim and matching with the Decidim
configurations:

```
ISSUER=http://127.0.0.1:8888/
GDPR_API_AUDIENCE=exampleapi
GDPR_API_AUTHORIZATION_FIELD=scope
GDPR_API_QUERY_SCOPE=gdprquery
GDPR_API_DELETE_SCOPE=gdprdelete
GDPR_API_URL=http://localhost:3000/gdpr-api/v1/profiles/$user_uuid
PROFILE_ID=65d4015d-1736-4848-9466-25d43a1fe8c7
USER_UUID=9e14df7c-81f6-4c41-8578-6aa7b9d0e5c0
LOA=substantial
SID=00000000-0000-4000-9000-000000000001
```

Also note that at the time of writing this, there was the following issue with
the testing tool that requires the described fix in the tool's `routes.py` file
for the tool to work correctly with this module:

https://github.com/City-of-Helsinki/profile-gdpr-api-tester/issues/5

During testing, change the following configuration at the Decidim's side within
the `.rben-vars` file (assuming you are using rbenv) and restart the server:

```
# During GDPR API testing, this needs to match the issuer configuration at the
# testing tool and the port where the testing tool's OIDC server is running at.
HELSINKIPROFILE_AUTH_URI=http://127.0.0.1:8888/
```

Before running the tester, we need to add a user to Decidim with the same UUID
as is configured for the tester (`USER_UUID`). In order to do this, run the
following rake task through the console:

```bash
$ bundle exec rake decidim:helsinki_profile:create_test_user[1,9e14df7c-81f6-4c41-8578-6aa7b9d0e5c0,gdprtest@example.org]
```

The arguments for the command are the following:

1. The organization where the user is created at
2. The UUID for the user record at the "other side" (i.e. Helsinki profile)
3. The email address of the user at Decidim

Now run the Helsinki profile GDPR API Tester tool and test the commands `query`,
`delete dryrun` and `delete` to verify the integration is working properly.

Finally, if you want to test the authorization of users against the Helsinki
profile GraphQL API, you will need to setup the
[Open city profile](https://github.com/City-of-Helsinki/open-city-profile)
application locally on your machine following its installation instructions. It
is also fine to test this on the staging server once everything else is
confirmed to be working. Note that if you run the Open city profile application
locally on your machine, you need to use a different port than `8080` for it in
case you are already running Keycloak on that port.

### Using with the actual Helsinki profile service (dev/test/stage/prod)

Once everything has been tested locally, you can request the Helsinki profile
team to add the necessary details for the service at the Helsinki profile's
side. You will need to create an integration page for the service at the
Helsinki profile's documentation to initiate the integration process.

You will need the following details that will be configured through the
application secrets as explained above in the installation instructions:

- `HELSINKIPROFILE_AUTH_URI`: The authentication (Keycloak) server's URI, which
  is different for different application environments (dev/test/stage/prod).
  * The URI for the Keycloak authentication server available from the Helsinki
    profile documentation.
- `HELSINKIPROFILE_AUTH_CLIENT_ID`: The configured authentication client ID
  which is used for the normal OIDC authentication flow.
  * Provided by the Helsinki profile team.
- `HELSINKIPROFILE_AUTH_CLIENT_SECRET`: The configured authentication client
  secret which is used for the normal OIDC authentication flow.
  * Provided by the Helsinki profile team.
- `HELSINKIPROFILE_PROFILE_API_URI`: The full URI for the Helsinki profile's
  GraphQL API, including the GraphQL endpoint path at the end of the URI.
  * You can find the correct URI from the
    [Open city profile documentation](https://github.com/City-of-Helsinki/open-city-profile#environments).
- `HELSINKIPROFILE_PROFILE_API_CLIENT_ID`: The authenticating client ID for
  which the access token is requested to access the
  * You can find the correct client ID from the Helsinki profile's documentation
    for each application environment (dev/test/stage/prod).
- `HELSINKIPROFILE_GDPR_CLIENT_ID`: The GDPR client ID which will be connecting
  to the Decidim's GDPR API endpoints. This client ID is agreed with the
  Helsinki profile's team and should be available through the integration page
  of the connecting service, i.e. Decidim.
  * Provided by the Helsinki profile team.

## Customization

For some specific needs, you may need to store extra metadata for the Helsinki
profile authorization or add new authorization configuration options for the
authorization.

This can be achieved by applying the following configuration to the module
inside the initializer described above:

```ruby
# config/initializers/helsinki_profile.rb

Decidim::HelsinkiProfile.configure do |config|
  # ... keep the default configuration as is ...
  # Add this extra configuration:
  config.workflow_configurator = lambda do |workflow|
    workflow.expires_in = 90.days
    workflow.action_authorizer = "CustomHelsinkiProfileActionAuthorizer"
    workflow.options do |options|
      options.attribute :custom_option, type: :string, required: false
    end
  end
  config.metadata_collector_class = CustomHelsinkiProfileMetadataCollector
end
```

For the workflow configuration options, please refer to the
[decidim-verifications documentation](https://github.com/decidim/decidim/tree/master/decidim-verifications).

For the custom metadata collector, please extend the default class as follows:

```ruby
# frozen_string_literal: true

class CustomHelsinkiProfileMetadataCollector < Decidim::HelsinkiProfile::Verification::MetadataCollector
  def metadata
    super.tap do |data|
      # You can access the OAuth raw info attributes using the `raw_info`
      # accessor:
      data[:extra] = raw_info[:extra_data]
    end
  end
end
```

## Contributing

See [Decidim](https://github.com/decidim/decidim).

### Testing

To run the tests run the following in the gem development path:

```bash
$ bundle
$ DATABASE_USERNAME=<username> DATABASE_PASSWORD=<password> bundle exec rake test_app
$ DATABASE_USERNAME=<username> DATABASE_PASSWORD=<password> bundle exec rspec
```

Note that the database user has to have rights to create and drop a database in
order to create the dummy test app database.

In case you are using [rbenv](https://github.com/rbenv/rbenv) and have the
[rbenv-vars](https://github.com/rbenv/rbenv-vars) plugin installed for it, you
can add these environment variables to the root directory of the project in a
file named `.rbenv-vars`. In this case, you can omit defining these in the
commands shown above.

### Test code coverage

If you want to generate the code coverage report for the tests, you can use
the `SIMPLECOV=1` environment variable in the rspec command as follows:

```bash
$ SIMPLECOV=1 bundle exec rspec
```

This will generate a folder named `coverage` in the project root which contains
the code coverage report.

## License

See [LICENSE-AGPLv3.txt](LICENSE-AGPLv3.txt).
