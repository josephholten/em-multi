#include <emscripten.h>
#include <stdio.h>
#include <thread>
#include <cstddef>
#include <cstdlib>
#include <vector>
#include <chrono>
#include <tbb/tbb.h>
#include <functional>
#include <unordered_map>
#include <mutex>
#include <iostream>

using namespace std::literals;

std::vector<double> a;
std::vector<double> b;
std::unordered_map<std::thread::id, std::once_flag> c;
std::mutex m;

void scalarprod(double* sum, double* a, double* b, size_t n) {
    std::call_once(c[std::this_thread::get_id()], [&](){
        std::unique_lock l{m};
        std::cout << "using thread: " << std::this_thread::get_id()<< std::endl;
    });
    double s = 0;
    for (size_t i = 0; i < n; i++)
        s += a[i]*b[i];
    *sum = s;
}

extern "C" {
EMSCRIPTEN_KEEPALIVE
void random_init(size_t n) {
    printf("filling random vectors...\n");
    a = std::vector<double>(n);
    b = std::vector<double>(n);

    std::srand(std::time(0));

    for (size_t i = 0; i < n; i++)
        a[i] = (double)rand() / RAND_MAX;
    for (size_t i = 0; i < n; i++)
        b[i] = (double)rand() / RAND_MAX;
}

EMSCRIPTEN_KEEPALIVE
void sequential() {
    printf("calculating sequential scalarproduct...\n");
    auto start = std::chrono::high_resolution_clock::now();
    double s;
    c.clear();
    scalarprod(&s, a.data(), b.data(), a.size());
    auto duration = std::chrono::high_resolution_clock::now() - start;
    printf("seq scalarprod: %lf\n", s);
    printf("seq time: %lldms\n", duration / 1ms);
}

EMSCRIPTEN_KEEPALIVE
void cpp_threads(size_t P) {
    printf("calculating cpp_threads scalarproduct...\n");
    printf("cpp_threads concurrency: %zu\n", P);

    auto start = std::chrono::high_resolution_clock::now();
    std::vector<std::thread> threads;
    std::vector<double> results(P);
    size_t chunk = a.size() / P;
    c.clear();
    for (size_t rank = 0; rank < P; rank++)
        threads.push_back(
            std::thread(scalarprod, &results[rank], a.data() + chunk*rank, b.data() + chunk*rank, chunk)
        );
    for (size_t rank = 0; rank < P; rank++)
        threads[rank].join();
    double sum = 0;
    for (double s : results)
        sum += s;
    auto duration = std::chrono::high_resolution_clock::now() - start;
    printf("cpp_threads scalarprod: %lf\n", sum);
    printf("cpp_threads time: %lldms\n", duration / 1ms);
}

EMSCRIPTEN_KEEPALIVE
void tbb_threads() {
    printf("calculating tbb_threads scalarproduct...\n");
    printf("tbb_threads concurrency: %d\n", tbb::info::default_concurrency());

{
#pragma optimize("", off)
            auto concurrency = std::thread::hardware_concurrency();
            if (concurrency > 1) {
                tbb::task_arena arena;
                arena.initialize(concurrency, 1, tbb::task_arena::priority::high);
                int start = 0, len = concurrency * 5;
                for (int i = 0; i < concurrency; ++i) {
                    tbb::parallel_for(start, len, [](size_t i) {
                    // printf("thread id %d\n", std::this_thread::get_id());
                    });
                }
            }
#pragma optimize("", on)
        }

    auto start = std::chrono::high_resolution_clock::now();
    c.clear();
    double s = tbb::parallel_reduce(
        tbb::blocked_range<size_t>(0, a.size()),
        0.0,
        [&](tbb::blocked_range<size_t> r, double sum) {
            scalarprod(&sum, &a[r.begin()], &b[r.begin()], r.end() - r.begin());
            return sum;
        },
        [](double a, double b) { return a+b;}
    );
    auto duration = std::chrono::high_resolution_clock::now() - start;
    printf("tbb_threads scalarprod: %lf\n", s);
    printf("tbb_threads time: %lldms\n", duration / 1ms);
}
}
