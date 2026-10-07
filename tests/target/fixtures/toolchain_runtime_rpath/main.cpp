#include <iostream>
#include <string>
#include <unordered_map>

std::string fixture_greeting ();

// A string-keyed hash map and iostream need the newer symbols of the C++
// runtime that built the program (libstdc++ 13, libc++ 23): an older runtime
// found by the loader stops it before main or at the first hash.
int
main ()
{
  std::unordered_map<std::string, int> counts;
  ++counts[fixture_greeting ()];
  std::cout << counts.size () << '\n';
  return counts.size () == 1 ? 0 : 1;
}
