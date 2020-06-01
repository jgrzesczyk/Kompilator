## Języki formalne i teoria translacji 2018/19

Kompilator prostego języka imperatywnego.

### Testowane w środowisku

* bison - v.```3.0.4```
* g++ - v.```7.3.0```
* flex - v.```2.6.4```

### Pliki projektu

* ```4.l``` - lekser języka imperatywnego
* ```4.y``` - parser języka imperatywnego
* ```makefile``` - program kompilujący powyższe pliki tworząc plik ```kompilator```

### Użycie
```kompilator <input> <output>```, gdzie ```input``` to plik napisany językiem imperatywnym, a ```output``` to kod maszyny rejestrowej.
