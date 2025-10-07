#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync, spawnSync } = require('child_process');

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

function extractExpectedOutputs(hxFile) {
    const content = fs.readFileSync(hxFile, 'utf8');
    const matches = content.matchAll(/\/\/\s*EXPECTED_OUTPUT:\s*"([^"]+)"/g);
    return Array.from(matches).map(m => m[1]);
}

function createResult(name, status, message) {
    return { name, status, message };
}

function buildHaxeCommand(baseName) {
    return `haxe lib.hxml -cp tests/compile-errors -main ${baseName} -js bin/compile-tests/${baseName}.js`;
}

function runErrorTest(hxFile, baseName, content) {
    const projectRoot = path.resolve(COMPILE_ERRORS_DIR, '../..');

    let expectedError;
    try {
        expectedError = extractExpectedError(hxFile);
    } catch (e) {
        return createResult(baseName, 'fail', e.message);
    }

    try {
        // Run haxe compiler - should fail
        execSync(buildHaxeCommand(baseName), {
            cwd: projectRoot,
            encoding: 'utf8',
            stdio: 'pipe'
        });

        // If we get here, compilation succeeded when it should have failed
        return createResult(
            baseName,
            'fail',
            `Compilation succeeded, but expected error: "${expectedError}"`
        );
    } catch (error) {
        // Compilation failed as expected - check error message
        const stderr = error.stderr || error.stdout || '';

        if (stderr.includes(expectedError)) {
            return createResult(
                baseName,
                'pass',
                `Got expected error: "${expectedError}"`
            );
        } else {
            return createResult(
                baseName,
                'fail',
                `Got different error than expected.\nExpected: "${expectedError}"\nActual output:\n${stderr}`
            );
        }
    }
}

function runOutputTest(hxFile, baseName, content) {
    const projectRoot = path.resolve(COMPILE_ERRORS_DIR, '../..');
    const expectedOutputs = extractExpectedOutputs(hxFile);

    // Use spawnSync to capture output even on success (warnings don't cause non-zero exit)
    const result = spawnSync('haxe', [
        'lib.hxml',
        '-cp', 'tests/compile-errors',
        '-main', baseName,
        '-js', `bin/compile-tests/${baseName}.js`
    ], {
        cwd: projectRoot,
        encoding: 'utf8',
        shell: true  // Use shell to ensure PATH is searched
    });

    // Check for spawn error
    if (result.error) {
        return createResult(
            baseName,
            'fail',
            `Failed to spawn process: ${result.error.message}`
        );
    }

    // Check stderr and stdout for expected output
    const output = (result.stderr || '') + (result.stdout || '');

    // Check if all expected outputs are present
    const missingOutputs = expectedOutputs.filter(expected => !output.includes(expected));

    if (missingOutputs.length === 0) {
        return createResult(
            baseName,
            'pass',
            `Got all expected outputs (${expectedOutputs.length})`
        );
    } else {
        return createResult(
            baseName,
            'fail',
            `Missing expected outputs:\n${missingOutputs.map(o => `  - "${o}"`).join('\n')}\n\nActual output:\n${output}\nExit code: ${result.status}`
        );
    }
}

function runCompileTest(hxFile) {
    const baseName = path.basename(hxFile, '.hx');
    const content = fs.readFileSync(hxFile, 'utf8');

    if (content.includes('EXPECTED_ERROR:')) {
        return runErrorTest(hxFile, baseName, content);
    } else if (content.includes('EXPECTED_OUTPUT:')) {
        return runOutputTest(hxFile, baseName, content);
    }

    return createResult(
        baseName,
        'fail',
        'No EXPECTED_ERROR or EXPECTED_OUTPUT comments found'
    );
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
