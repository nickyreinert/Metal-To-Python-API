
import numpy as np
import ctypes
import time
import math
import time

if __name__ == "__main__":

    numItems = 1_000_000_000
    silent = True

    # Step 1: Create an array of sequential floats from 0 to numItems-1
    input_array = np.linspace(0, numItems - 1, numItems, dtype="float32")  # Sequential floats

    # Measure the time for the cosine computation
    start_time = time.time()
    
    # Step 2: Compute the cosine of the input array
    output_array = np.cos(input_array)

    end_time = time.time()
    computation_time = end_time - start_time
    
    # Check and print combined results
    combined_results = np.column_stack((input_array, output_array))
    if not silent:
        print("Input and Output (Cosine):")
        print(combined_results)
    
    print(f"Computation time: {computation_time:.6f} seconds; {numItems:,.0f} items")