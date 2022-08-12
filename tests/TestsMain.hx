function main() {
    var runner = new utest.Runner();
    runner.addCases('cases');
    utest.ui.Report.create(runner, NeverShowSuccessResults, AlwaysShowHeader);
    runner.run();
}
