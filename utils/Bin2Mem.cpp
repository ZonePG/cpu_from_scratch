#include <iostream>
#include <fstream>
#include <string>
#include <cstring>

void Bin2Mem(const std::string& src, const std::string& trg) {
    std::ifstream fin(src, std::ifstream::in);
    if (!fin) {
        std::cerr << "failed to open source file" << src << std::endl;
        exit(1);
    }
    std::ofstream fout(trg, std::ofstream::out);
    if (!fout) {
        std::cerr << "failed to open target file" << src << std::endl;
        exit(1);
    }
    fout << std::hex;
    char ch;
    int count = 0;
    while (fin.get(ch)) {
        count++;
        int value = static_cast<unsigned char>(ch);
        if (value < 0x10)
            fout << '0';
        fout << value;
        if (count % 4 == 0)
            fout << '\n';
    }
    fin.close();
    fout.close();
}

int main(int argc, char *argv[]) {
    if (argc != 5 && !strcmp(argv[1], "-f") && !strcmp(argv[3], "-o")) {
        std::cerr << "command -f sourcefile.bin -o targetfile.data";
        exit(1);
    }
    
    std::string source_filename = argv[2];
    std::string target_filename = argv[4];

    Bin2Mem(source_filename, target_filename);
}