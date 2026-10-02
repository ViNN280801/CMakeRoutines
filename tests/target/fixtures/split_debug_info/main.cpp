int fixture_value(int x);

int main(int argc, char **) { return fixture_value(argc) == 4 ? 0 : 1; }
