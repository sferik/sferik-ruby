# Contributing

1. Fork the repository and create a branch.
2. Run `bin/setup`.
3. Make your change, with specs. The fixtures in `spec/fixtures/` are responses saved from the API.
4. Run `bundle exec rake`: the specs must keep 100% line, branch, and method coverage, the linters must pass, and
   [mutant](https://github.com/mbj/mutant) must kill every mutation. For a mutation that survives, either add a spec
   that tells it apart, or, if it means the same thing, change the code to the mutation.
5. Open a pull request.
