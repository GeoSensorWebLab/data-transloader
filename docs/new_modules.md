# Instructions for New Modules

1. Create documentation for module usage
2. Create module directory in `lib/transloader`
3. Add basic `ontology.rb`, `provider.rb`, `README.md`, and `station.rb` to module directory
4. Update `transload` script with new module
5. Add module-specific command-line options to `command_line_option_parser.rb` if necessary
6. Update `command_line_options.rb` with new module
7. Update `transloader/station.rb` to reference module-specific station class
8. Update `lib/transloader.rb` to include new module classes
9. Add module-specific testing Bash script to `test` directory
10. Build out module classes while using test script with the Vagrant test VM running FROST SensorThings API instance
11. Update module documentation with any changes, if necessary
12. Refactor module to remove and redundant code and increase clarity, adding RSpec tests as necessary
13. Update base `README.markdown` with link to specific docs
