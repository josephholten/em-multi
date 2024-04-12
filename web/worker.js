import wasm from "./multi.js"

onmessage = (e) => {
    wasm().then(instance => {
    instance.ccall("random_init", null, ["number"], [Math.pow(2, 26)])
    instance.ccall("sequential", null, [], [])
    instance.ccall("cpp_threads", null, ["number"], [4])
    instance.ccall("tbb_threads", null, [], [])
    })
}

