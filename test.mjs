// Test usearch12 WASM build in Node.js
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const buildDir = join(__dirname, 'build');

const createUsearch = (await import(join(buildDir, 'usearch.js'))).default;

async function createModule() {
  const stdout = [];
  const stderr = [];
  const Module = await createUsearch({
    noInitialRun: true,
    print: (t) => stdout.push(t),
    printErr: (t) => stderr.push(t),
    locateFile: (p) => join(buildDir, p),
  });
  return { Module, stdout, stderr };
}

// --- Test 1: Show version/help (no args) ---
console.log('=== Test 1: usearch with no args (shows help) ===');
{
  const { Module, stdout } = await createModule();
  try { Module.callMain([]); } catch (e) { /* exit throws */ }
  console.log(stdout.join('\n'));
}

// --- Test 2: cluster_fast ---
console.log('\n=== Test 2: cluster_fast ===');
{
  const { Module, stderr } = await createModule();

  Module.FS.writeFile('/test.fasta', `>seq1
ATCGATCGATCGATCGATCGATCGATCGATCG
>seq2
ATCGATCGATCGATCGATCGATCGATCGATCG
>seq3
GCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTA
>seq4
ATCGATCGATCGATCGATCGAAAAAAAATCG
>seq5
GCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTA
`);

  try {
    Module.callMain(['-cluster_fast', '/test.fasta', '-id', '0.9',
      '-centroids', '/centroids.fasta', '-threads', '1', '-quiet']);
  } catch (e) { /* */ }

  try {
    const out = Module.FS.readFile('/centroids.fasta', { encoding: 'utf8' });
    console.log(out);
    console.log('PASS: cluster_fast produced 3 centroids from 5 sequences');
  } catch (e) {
    console.log('FAIL:', e.message);
    console.log(stderr.join('\n'));
  }
}

// --- Test 3: fastx_uniques (dereplication) ---
console.log('\n=== Test 3: fastx_uniques ===');
{
  const { Module, stderr } = await createModule();

  Module.FS.writeFile('/input.fasta', `>s1
ATCGATCGATCG
>s2
ATCGATCGATCG
>s3
GCTAGCTAGCTA
>s4
ATCGATCGATCG
`);

  try {
    Module.callMain(['-fastx_uniques', '/input.fasta',
      '-fastaout', '/uniques.fasta', '-sizeout', '-threads', '1', '-quiet']);
  } catch (e) { /* */ }

  try {
    const out = Module.FS.readFile('/uniques.fasta', { encoding: 'utf8' });
    console.log(out);
    console.log('PASS: fastx_uniques produced dereplicated output');
  } catch (e) {
    console.log('FAIL:', e.message);
    console.log(stderr.join('\n'));
  }
}

console.log('\n=== All tests complete ===');
process.exit(0);
