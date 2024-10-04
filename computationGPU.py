
import numpy as np
import ctypes
import time
import math
import time

if __name__ == "__main__":

    numItems = 1_000_000_000
    silent = True

    # Loads dylib like dlopen
    swift_function = ctypes.CDLL(".build/debug/libWrapper.dylib")

    swift_function.benchmark.argtypes = [
        ctypes.POINTER(ctypes.c_float),
        ctypes.POINTER(ctypes.c_float),
        ctypes.c_int
    ]
        
    # Step 1: # Step 1: Create an array of random floats in the range [-1, 1]
    input_array = np.linspace(0, numItems - 1, 10, dtype="float32")  # Sequential floats from 1 to 10
    # input_array = np.random.uniform(-1, 1, numItems).astype("float32")  # Ensure float32 for GPU

    # Step 2: Convert input_array to a pointer
    input_ptr = input_array.ctypes.data_as(ctypes.POINTER(ctypes.c_float))

    # Step 3: Prepare for output
    output_length = len(input_array)
    output_mutable_ptr = (ctypes.c_float * output_length)()  # Create an output buffer

    # Start time measurement
    start_time = time.perf_counter()

    # Step 4: Call the Swift function and pass the output buffer
    swift_function.benchmark(input_ptr, output_mutable_ptr, output_length)

    # End time measurement
    end_time = time.perf_counter()
    
    # Calculate elapsed time
    elapsed_time = end_time - start_time

    # Step 5: Convert output pointer to a numpy array
    output_array = np.ctypeslib.as_array(output_mutable_ptr)

    # Check and print combined results
    combined_results = np.column_stack((input_array, output_array))
    if not silent:
        print("Input and Output:")
        print(combined_results)

    # Print elapsed time
    print(f"Computation time: {elapsed_time:.6f} seconds; {numItems:,.0f} items")
