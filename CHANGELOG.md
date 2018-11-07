# Changelog for Cldr_Currencies v2.0.0-rc.0

This is the changelog for Cldr_Currencies v1.1.0 released on October 18th, 2018.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/cldr_numbers/tags)

### Enhancements

* Updated dependency on [ex_cldr](https://hex.pm/packages/ex_cldr) to version 1.8 which uses CLDR version 34 data.

* Remove Poison from optional dependencies (can still be configured in a cliuent app)

### Breaking Changes

* Currency.currency_for_code changed parameters:  code, backend, options where options locale is required
