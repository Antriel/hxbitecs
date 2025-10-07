#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const COMPILE_ERRORS_DIR = __dirname;
const RESET = '\x1b[0m';
const RED = '\x1b[31m';
const GREEN = '\x1b[32m';
const YELLOW = '\x1b[33m';
const CYAN = '\x1b[36m';

function extractExpectedError(hxFile) {
    const content = fs.readFileSync(hxFile, 'utf8');
    const match = content.match(/\/\/\s*EXPECTED_ERROR:\s*"([^"]+)"/);
    if (!match) {
        throw new Error(`No EXPECTED_ERROR comment found in ${path.basename(hxFile)}`);
    }
    return match[1];
}

function runCompileTest(hxFile) {
    const baseName = path.basename(hxFile, '.hx');
    const projectRoot = path.resolve(COMPILE_ERRORS_DIR, '../..');

    let expectedError;
    try {
        expectedError = extractExpectedError(hxFile);
    } catch (e) {
        return {
            name: baseName,
            status: 'fail',
            message: e.message
        };
    }

    try {
        // Run haxe compiler - should fail
        // Generate CLI args equivalent to: lib.hxml, -cp tests/compile-errors, -main ClassName, -js output.js
        execSync(`haxe lib.hxml -cp tests/compile-errors -main ${baseName} -js bin/compile-tests/${baseName}.js`, {
            cwd: projectRoot,
            encoding: 'utf8',
            stdio: 'pipe'
        });

        // If we get here, compilation succeeded when it should have failed
        return {
            name: baseName,
            status: 'fail',
            message: `Compilation succeeded, but expected error: "${expectedError}"`
        };
    } catch (error) {
        // Compilation failed as expected - check error message
        const stderr = error.stderr || error.stdout || '';

        if (stderr.includes(expectedError)) {
            return {
                name: baseName,
                status: 'pass',
                message: `Got expected error: "${expectedError}"`
            };
        } else {
            return {
                name: baseName,
                status: 'fail',
                message: `Got different error than expected.\nExpected: "${expectedError}"\nActual output:\n${stderr}`
            };
        }
    }
}

function main() {
    console.log(`${CYAN}Running compile-fail tests...${RESET}\n`);

    const hxFiles = fs.readdirSync(COMPILE_ERRORS_DIR)
        .filter(f => f.endsWith('.hx'))
        .sort();

    if (hxFiles.length === 0) {
        console.log(`${YELLOW}No compile-fail tests found.${RESET}`);
        return;
    }

    const results = hxFiles.map(hxFile =>
        runCompileTest(path.join(COMPILE_ERRORS_DIR, hxFile))
    );

    // Print results
    let passed = 0;
    let failed = 0;
    let skipped = 0;

    results.forEach(result => {
        const statusSymbol = result.status === 'pass' ? `${GREEN}✓${RESET}` :
                           result.status === 'fail' ? `${RED}✗${RESET}` :
                           `${YELLOW}⊘${RESET}`;

        console.log(`${statusSymbol} ${result.name}`);

        if (result.status === 'fail') {
            console.log(`  ${RED}${result.message}${RESET}\n`);
            failed++;
        } else if (result.status === 'pass') {
            passed++;
        } else {
            skipped++;
        }
    });

    // Summary
    console.log(`\n${'='.repeat(50)}`);
    console.log(`${GREEN}Passed: ${passed}${RESET} | ${RED}Failed: ${failed}${RESET} | ${YELLOW}Skipped: ${skipped}${RESET}`);
    console.log(`Total: ${results.length}`);

    if (failed > 0) {
        console.log(`\n${RED}Some compile-fail tests failed.${RESET}`);
        process.exit(1);
    } else {
        console.log(`\n${GREEN}All compile-fail tests passed!${RESET}`);
    }
}

main();
