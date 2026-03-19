#!/bin/bash
# ============================================================
# Compile usearch12 to WebAssembly
# Runs inside Docker container with emscripten/emsdk
# ============================================================
set -e

SRCDIR="/work/src/src"
OUTDIR="/work/build"
PATCHDIR="/work/patches"

rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"

# --- Apply patches ---
echo "=== Applying patches ==="

# Patch 1: Fix int64/uint64 typedefs for wasm32
# On wasm32, 'long' is 32-bit, so we need 'long long' for 64-bit integers
if ! grep -q '__EMSCRIPTEN__' "$SRCDIR/myutils.h"; then
  sed -i 's/#elif defined(__GNUC__)/#elif defined(__EMSCRIPTEN__)\ntypedef long long int64;\ntypedef unsigned long long uint64;\n#elif defined(__GNUC__)/' "$SRCDIR/myutils.h"
  echo "Patched myutils.h: int64/uint64 typedefs for wasm32"
fi

# Patch 2: Add emscripten fallback for GetMemUseBytes/GetPhysMemBytes/GetCPUCoreCount
# The code has #ifdef cascades for _MSC_VER, linux, __MACH__, with a bare #else fallback.
# For GetCPUCoreCount, the non-MSVC path uses sysconf which emscripten supports,
# but we'll force single core to keep it simple.

# Patch 3: Fix GetCPUCoreCount for emscripten (return 1)
if ! grep -q 'EMSCRIPTEN' "$SRCDIR/myutils.cpp"; then
  # Add emscripten block before the linux block for GetPhysMemBytes
  sed -i 's/#elif\tlinux || __linux__ || __CYGWIN__/#elif defined(__EMSCRIPTEN__)\ndouble GetPhysMemBytes()\n\t{\n\treturn 1024.0 * 1024.0 * 1024.0; \/\/ Report 1GB\n\t}\n\ndouble GetMemUseBytes()\n\t{\n\treturn 0.0;\n\t}\n\n#elif\tlinux || __linux__ || __CYGWIN__/' "$SRCDIR/myutils.cpp"
  echo "Patched myutils.cpp: Added emscripten memory stubs"
fi

echo "=== Compiling usearch12 to WebAssembly ==="

# --- C source files (bundled zlib) ---
C_SOURCES="
adler32.c
crc32.c
deflate.c
gzlib.c
gzread.c
infback.c
inffast.c
inflate.c
inftrees.c
trees.c
zutil.c
"

# --- C++ source files ---
CXX_SOURCES="
accepter.cpp
alignresult.cpp
alnheuristics.cpp
alnout.cpp
alnparams.cpp
alpha.cpp
alpha2.cpp
alphainfo.cpp
arscorer.cpp
bimeradp.cpp
bitmapsearcher.cpp
bitvec.cpp
bitvec64.cpp
blast6out.cpp
blosum62.cpp
chainer1.cpp
chainer.cpp
chimehit.cpp
chunksearcher.cpp
closedrefsink.cpp
clusterfast.cpp
clustermt.cpp
clustersink.cpp
clustersmallmem.cpp
cmd.cpp
comppath.cpp
constaxf.cpp
constaxsink.cpp
constaxstr.cpp
countsort.cpp
dbhitsink.cpp
deparser.cpp
derepfull.cpp
derepresult.cpp
diagbox.cpp
dustmask.cpp
estats.cpp
evalue.cpp
fastaseqsource.cpp
fastqfilter2.cpp
fastxgetsamplenames.cpp
fastmask.cpp
fastq.cpp
fastqfilter.cpp
fastqjoin.cpp
fastqmerge.cpp
fastqseqsource.cpp
fastxtruncate.cpp
filetype.cpp
fileseqsource.cpp
findgene.cpp
finger.cpp
genefinder.cpp
getcmd.cpp
getfastqs.cpp
getglobalhsps.cpp
gethsps.cpp
getuniquelettercount.cpp
globalaligner.cpp
globalalignmem.cpp
makeclustersearcher.cpp
mergealign.cpp
gzipfileio.cpp
hitmgr.cpp
hspfinder.cpp
interp.cpp
json.cpp
label.cpp
linereader.cpp
lnfrac.cpp
loaddb.cpp
localaligner.cpp
localaligner2.cpp
localmulti.cpp
logaln.cpp
make3way.cpp
makedbsearcher.cpp
makeudb.cpp
mask.cpp
mergepair.cpp
mergepost.cpp
mergepre.cpp
mergestats.cpp
mergethread.cpp
mx.cpp
mymutex.cpp
myutils.cpp
objmgr.cpp
fragaligner.cpp
opts.cpp
orffinder.cpp
orient.cpp
otutab.cpp
otutabsink.cpp
outputsink.cpp
outputuc.cpp
pathinfo.cpp
prime.cpp
progress.cpp
quarts.cpp
search.cpp
searchcmd.cpp
searcher.cpp
segmaskseq.cpp
seqdb.cpp
seqdbfromfasta.cpp
seqdbio.cpp
seqdbsearcher.cpp
seqdbseqsource.cpp
seqhash.cpp
seqinfo.cpp
seqsource.cpp
setnucmx.cpp
sintaxsummary.cpp
sintaxsearcher.cpp
staralign.cpp
strdict.cpp
substmx.cpp
tax.cpp
taxy.cpp
terminator.cpp
test.cpp
tracebackbitmem.cpp
uchime3denovo.cpp
udbbuild.cpp
udb2bitvec.cpp
udbusortedsearcherbig.cpp
udbdata.cpp
udbio.cpp
udbparams.cpp
udbsearcher.cpp
udbusortedsearcher.cpp
ungappedblast.cpp
unoise3.cpp
uparsesink.cpp
uparsedp.cpp
uparsepretty.cpp
upclustersink.cpp
usearch_main.cpp
userout.cpp
viterbifastbandmem.cpp
viterbifastmem.cpp
wordcounter.cpp
wordparams.cpp
xdropalignmem.cpp
xdropbwdmem.cpp
xdropbwdsplit.cpp
xdropfwdmem.cpp
xdropfwdsplit.cpp
"

COMMON_FLAGS="-DNDEBUG -O2 -fexceptions"
CFLAGS="$COMMON_FLAGS"
CXXFLAGS="$COMMON_FLAGS -std=c++11 -pthread"

# --- Compile C files ---
echo "--- Compiling C sources ---"
cd "$SRCDIR"
for f in $C_SOURCES; do
  echo "  CC  $f"
  emcc $CFLAGS -c -o "$OUTDIR/$(basename $f .c).o" "$f"
done

# --- Compile C++ files ---
echo "--- Compiling C++ sources ---"
for f in $CXX_SOURCES; do
  echo "  CXX $f"
  em++ $CXXFLAGS -c -o "$OUTDIR/$(basename $f .cpp).o" "$f"
done

# --- Link ---
echo "--- Linking ---"
OBJECTS=$(ls "$OUTDIR"/*.o)

em++ $OBJECTS \
  -O2 \
  -fexceptions \
  -s WASM=1 \
  -s ALLOW_MEMORY_GROWTH=1 \
  -s MAXIMUM_MEMORY=4GB \
  -s INITIAL_MEMORY=256MB \
  -s EXPORTED_FUNCTIONS="['_main']" \
  -s EXPORTED_RUNTIME_METHODS="['callMain','FS']" \
  -s MODULARIZE=1 \
  -s EXPORT_NAME='createUsearch' \
  -s ENVIRONMENT='web,node,worker' \
  -s DISABLE_EXCEPTION_CATCHING=0 \
  -s EXIT_RUNTIME=0 \
  -s INVOKE_RUN=0 \
  -s PTHREAD_POOL_SIZE=4 \
  -pthread \
  -o "$OUTDIR/usearch.js"

echo ""
echo "=== Build complete ==="
ls -lh "$OUTDIR/usearch.js" "$OUTDIR/usearch.wasm" "$OUTDIR/usearch.worker.js" 2>/dev/null || true
echo ""
