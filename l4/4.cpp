#include <iostream>
#include <vector>
#include <cstdlib>
#include <ctime>

int main()
{
    std::vector < int > tab;
    srand( time( NULL ) );
    //zapis
    tab.push_back( 0 );
    for( int i = 0; i < 10; i++ )
    {
        int gdzie = rand() % tab.size();
        tab.insert( tab.begin() + gdzie, i );
        for( int j = 0; j < tab.size(); j++ )
        {
            std::cout << tab[ j] << " ";
        }
    std::cout << std::endl;
    }
    //odczyt
    
    return 0;
}