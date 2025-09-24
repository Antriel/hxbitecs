function main() {
    var runner = new utest.Runner();
    runner.addCases('externs'); // Simple externs tests. No macros.
    utest.ui.Report.create(runner, NeverShowSuccessResults, AlwaysShowHeader);
    runner.run();
}
