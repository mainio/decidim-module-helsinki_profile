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

1. Helsinki profile OmniAuth provider in order to sign in with Helsinki profile.
2. Helsinki profile authorization in order to authorize users using the
   Helsinki profile user data.
3. Helsinki profile GDPR API endpoints that allows the centralized Helsinki
   profile application to do programmatic GDPR requests to Decidim (e.g.
   download your data or delete the profile).

To enable the OmniAuth flow or the Helsinki profile authorization, you need to
sign in to the Decidim system management panel. After enabled from there, you
can start using them.

Using the Helsinki profile OmniAuth sign in method will automatically authorize
the users during their sign ins. This way they do not have to separately sign in
and authorize themselves using the same identity provider.

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
