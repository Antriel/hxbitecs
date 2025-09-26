function main() {
    var runner = new utest.Runner();
    runner.addCases('externs'); // Simple externs tests. No macros.
    runner.addCases('behaviors'); // Testing how bitECS behaves in certain scenarios.
    runner.addCases('hardcoded'); // Manually written code that macros are meant to generate.
    runner.addCase(new macros.TestStoreMacro());
    utest.ui.Report.create(runner, NeverShowSuccessResults, AlwaysShowHeader);
    runner.run();
}
