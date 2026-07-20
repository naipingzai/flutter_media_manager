#ifndef FFI_EXPORT_H
#define FFI_EXPORT_H

// Ensure symbols are exported on all platforms
#if defined(_WIN32)
  #define FFI_EXPORT __declspec(dllexport)
#elif defined(__APPLE__) || defined(__linux__)
  #define FFI_EXPORT __attribute__((visibility("default")))
#else
  #define FFI_EXPORT
#endif

#endif // FFI_EXPORT_H
