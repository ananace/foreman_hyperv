# Foreman Hyper-V

[![Gem Version](https://badge.fury.io/rb/foreman_hyperv.svg)](https://badge.fury.io/rb/foreman_hyperv)

Microsoft Hyper-V compute resource for Foreman

Uses the in-development `fog-hyperv` gem found [here](https://github.com/ananace/fog-hyperv).

## Nota Bene

Currently the plugin only supports Hyper-V hosts where the names are well defined in DNS and in connection strings, avoid using IP addresses for now.

If you're using SELinux, you may need to enable the connect_all boolean. For Foreman 2.0 and earlier, run `setsebool -P passenger_can_connect_all 1`. For Foreman 2.1 and later the command would be `setsebool -P foreman_rails_can_connect_all 1`.

## Testing/Installing

Follow the Foreman manual for [advanced installation from gems](https://theforeman.org/plugins/#2.3AdvancedInstallationfromGems) for `fog-hyperv` and `foreman_hyperv`.

There are RPMs packaged for the `fog-hyperv` dependencies under [Release v0.0.1](https://github.com/ace13/foreman_hyperv/releases/tag/v0.0.1), or they too can be installed from gems.

Do bear in mind that this is still very early in development, so plenty of issues may exist.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ananace/foreman_hyperv.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

