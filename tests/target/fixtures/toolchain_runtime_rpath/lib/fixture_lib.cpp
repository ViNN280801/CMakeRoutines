#include <string>

std::string fixture_greeting ();

std::string
fixture_greeting ()
{
  return std::string ("runtime-") + std::to_string (42);
}
