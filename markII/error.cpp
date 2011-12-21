#include <iostream>
#include <cstdlib>

#include "error.hpp"

void sool::error(std::string str)
{
    std::cout << "Internal error: " << str << std::endl;
    exit(EXIT_FAILURE);
}
