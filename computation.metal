//
// xcrun -sdk macosx metal -fcikernel -c computation.metal -o computation.air;xcrun -sdk macosx metallib computation.air -o computation.metallib
//
#include <metal_stdlib>
using namespace metal;

struct UInt256 {
    uint32_t elements[8];
};

struct Point {
    UInt256 x;
    UInt256 y;
};

constant UInt256 _p = {0xFFFFFC2F, 0xFFFFFFFE, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF};
constant Point G = {{0x16F81798, 0x59F2815B, 0x2DCE28D9, 0x029BFCDB, 0xCE870B07, 0x55A06295, 0x9DCBBAC5, 0x79BE667E},
                    {0xFB10D4B8, 0x9C47D08F, 0xA6855419, 0xFD17B448, 0x0E1108A8, 0x5DA4FBFC, 0x26A3C465, 0x483ADA77}};

// Function declarations
UInt256 addMod(UInt256 a, UInt256 b, UInt256 m);
UInt256 subMod(UInt256 a, UInt256 b, UInt256 m);
UInt256 mulMod(UInt256 a, UInt256 b, UInt256 m);
UInt256 inverseMod(UInt256 a, UInt256 m);
Point doublePoint(Point p);
Point addPoints(Point p, Point q);
Point scalarMultiply(UInt256 k, Point p);

// Function implementations
UInt256 addMod(UInt256 a, UInt256 b, UInt256 m) {
    UInt256 result;
    uint64_t carry = 0;
    for (int i = 0; i < 8; i++) {
        uint64_t sum = (uint64_t)a.elements[i] + (uint64_t)b.elements[i] + carry;
        result.elements[i] = (uint32_t)sum;
        carry = sum >> 32;
    }
    if (carry || (result.elements[7] >= m.elements[7] && result.elements[6] >= m.elements[6] &&
                  result.elements[5] >= m.elements[5] && result.elements[4] >= m.elements[4] &&
                  result.elements[3] >= m.elements[3] && result.elements[2] >= m.elements[2] &&
                  result.elements[1] >= m.elements[1] && result.elements[0] >= m.elements[0])) {
        carry = 0;
        for (int i = 0; i < 8; i++) {
            uint64_t diff = (uint64_t)result.elements[i] - (uint64_t)m.elements[i] - carry;
            result.elements[i] = (uint32_t)diff;
            carry = (diff >> 32) & 1;
        }
    }
    return result;
}

UInt256 subMod(UInt256 a, UInt256 b, UInt256 m) {
    UInt256 result;
    int64_t borrow = 0;
    for (int i = 0; i < 8; i++) {
        int64_t diff = (int64_t)a.elements[i] - (int64_t)b.elements[i] - borrow;
        result.elements[i] = (uint32_t)diff;
        borrow = (diff < 0) ? 1 : 0;
    }
    if (borrow) {
        uint64_t carry = 0;
        for (int i = 0; i < 8; i++) {
            uint64_t sum = (uint64_t)result.elements[i] + (uint64_t)m.elements[i] + carry;
            result.elements[i] = (uint32_t)sum;
            carry = sum >> 32;
        }
    }
    return result;
}

UInt256 mulMod(UInt256 a, UInt256 b, UInt256 m) {
    UInt256 result = {0};
    for (int i = 0; i < 8; i++) {
        uint64_t carry = 0;
        for (int j = 0; j < 8; j++) {
            uint64_t product = (uint64_t)a.elements[i] * (uint64_t)b.elements[j] + (uint64_t)result.elements[i+j] + carry;
            if (i + j < 8) {
                result.elements[i+j] = (uint32_t)product;
            }
            carry = product >> 32;
        }
    }
    return addMod(result, {0}, m);
}

UInt256 inverseMod(UInt256 a, UInt256 m) {
    UInt256 low = {1};
    UInt256 high = {0};
    UInt256 temp_a = a;
    UInt256 temp_m = m;

    while ((temp_a.elements[0] != 0 || temp_a.elements[1] != 0 || temp_a.elements[2] != 0 || temp_a.elements[3] != 0 ||
            temp_a.elements[4] != 0 || temp_a.elements[5] != 0 || temp_a.elements[6] != 0 || temp_a.elements[7] != 0) &&
           (temp_m.elements[0] != 0 || temp_m.elements[1] != 0 || temp_m.elements[2] != 0 || temp_m.elements[3] != 0 ||
            temp_m.elements[4] != 0 || temp_m.elements[5] != 0 || temp_m.elements[6] != 0 || temp_m.elements[7] != 0)) {
        UInt256 q = {0};
        UInt256 temp_high = high;
        
        while (temp_m.elements[7] >= temp_a.elements[7]) {
            q.elements[0]++;
            temp_m = subMod(temp_m, temp_a, m);
        }
        
        high = subMod(high, mulMod(q, low, m), m);
        temp_a = temp_m;
        temp_m = temp_high;
        
        UInt256 temp = low;
        low = high;
        high = temp;
    }

    return high;
}

Point doublePoint(Point p) {
    if (p.x.elements[0] == 0 && p.y.elements[0] == 0) {
        return p;
    }
    
    UInt256 lambda = mulMod(p.x, p.x, _p);
    lambda = mulMod(lambda, {3}, _p);
    UInt256 y2 = addMod(p.y, p.y, _p);
    lambda = mulMod(lambda, inverseMod(y2, _p), _p);
    
    UInt256 x3 = mulMod(lambda, lambda, _p);
    x3 = subMod(x3, addMod(p.x, p.x, _p), _p);
    
    UInt256 y3 = subMod(p.x, x3, _p);
    y3 = mulMod(y3, lambda, _p);
    y3 = subMod(y3, p.y, _p);
    
    return {x3, y3};
}

Point addPoints(Point p, Point q) {
    if (p.x.elements[0] == 0 && p.y.elements[0] == 0) return q;
    if (q.x.elements[0] == 0 && q.y.elements[0] == 0) return p;
    
    bool same = true;
    for (int i = 0; i < 8; i++) {
        if (p.x.elements[i] != q.x.elements[i] || p.y.elements[i] != q.y.elements[i]) {
            same = false;
            break;
        }
    }
    if (same) return doublePoint(p);
    
    UInt256 lambda = subMod(q.y, p.y, _p);
    UInt256 xDiff = subMod(q.x, p.x, _p);
    lambda = mulMod(lambda, inverseMod(xDiff, _p), _p);
    
    UInt256 x3 = mulMod(lambda, lambda, _p);
    x3 = subMod(x3, p.x, _p);
    x3 = subMod(x3, q.x, _p);
    
    UInt256 y3 = subMod(p.x, x3, _p);
    y3 = mulMod(y3, lambda, _p);
    y3 = subMod(y3, p.y, _p);
    
    return {x3, y3};
}

Point scalarMultiply(UInt256 k, Point p) {
    Point result = {{0}, {0}};
    Point temp = p;
    
    for (int i = 0; i < 256; i++) {
        if ((k.elements[i / 32] >> (i % 32)) & 1) {
            result = addPoints(result, temp);
        }
        temp = doublePoint(temp);
    }
    
    return result;
}

kernel void calculatePublicKeys(device const uchar *privateKeys [[buffer(0)]],
                                device UInt256 *publicKeysX [[buffer(1)]],
                                device UInt256 *publicKeysY [[buffer(2)]],
                                device uchar *debugBuffer [[buffer(3)]],
                                uint id [[thread_position_in_grid]]) {
    UInt256 privateKey;
    for (int i = 0; i < 8; i++) {
        privateKey.elements[i] =
            (uint32_t)privateKeys[id * 32 + i * 4] |
            ((uint32_t)privateKeys[id * 32 + i * 4 + 1] << 8) |
            ((uint32_t)privateKeys[id * 32 + i * 4 + 2] << 16) |
            ((uint32_t)privateKeys[id * 32 + i * 4 + 3] << 24);
    }
    
    // Copy private key to debug buffer
    device uint32_t* debugBufferPrivate = (device uint32_t*)&debugBuffer[id * 128];
    for (int i = 0; i < 8; i++) {
        debugBufferPrivate[i] = privateKey.elements[i];
    }

    Point publicKey = scalarMultiply(privateKey, G);
    
    publicKeysX[id] = publicKey.x;
    publicKeysY[id] = publicKey.y;

    // Copy public key to debug buffer
    device uint32_t* debugBufferX = (device uint32_t*)&debugBuffer[id * 128 + 32];
    device uint32_t* debugBufferY = (device uint32_t*)&debugBuffer[id * 128 + 64];
    for (int i = 0; i < 8; i++) {
        debugBufferX[i] = publicKey.x.elements[i];
        debugBufferY[i] = publicKey.y.elements[i];
    }
}


/*
 TESTS
 */

bool testAddMod(device uint32_t* debug_output) {
    UInt256 a = {
        {0x11111111, 0x22222222, 0x33333333, 0x44444444,
         0x55555555, 0x66666666, 0x77777777, 0x88888888}
    };
    
    UInt256 b = {
        {0x99999999, 0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC,
         0xDDDDDDDD, 0xEEEEEEEE, 0xFFFFFFFF, 0x00000000}
    };
    
    UInt256 m = {
        {0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF,
         0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFE}
    };
    
    UInt256 expected = {
        {0xAAAAAAAA, 0xCCCCCCCC, 0xEEEEEEEE, 0x11111110,
         0x33333332, 0x55555554, 0x77777776, 0x88888888}
    };
    
    UInt256 actual = addMod(a, b, m);
    
    // Store debug output
    for (int i = 0; i < 8; i++) {
        debug_output[i] = a.elements[i];
        debug_output[i + 8] = b.elements[i];
        debug_output[i + 16] = m.elements[i];
        debug_output[i + 24] = actual.elements[i];
        debug_output[i + 32] = expected.elements[i];
    }
    
    // Compare result
    for (int i = 0; i < 8; i++) {
        if (actual.elements[i] != expected.elements[i]) {
            return false;
        }
    }
    
    return true;
}



// Structure to store test results
struct TestResult {
    uint32_t testPassed; // 1 for pass, 0 for fail
    UInt256 actual;      // Actual result from the function
    UInt256 expected;    // Expected result
};

kernel void runTests(device bool* results [[buffer(0)]], device uint32_t* debug_output [[buffer(1)]]) {
    results[0] = testAddMod(debug_output);
}

kernel void benchmark(device const float *inputData [[buffer(0)]],
                      device float *outputData [[buffer(1)]],
                      uint id [[thread_position_in_grid]]) {
    
    // Get the input data for the current thread
    float inputValue = inputData[id];
    
    // Compute the cosine of the input value
    float result = cos(inputValue);
    
    // Store the result of the computation in the output buffer
    outputData[id] = result; // Store the computed cosine
    
}
