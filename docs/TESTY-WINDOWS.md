# Plan testów na Windows 11

Status: plan do wykonania na komputerze z Windows 11; wykonanie testów należy odnotować wraz z wersją Windows, GG, modelem słuchawek i wynikiem. Nie traktuj samego przejścia CI jako dowodu działania fizycznego dźwięku.

1. Uruchom diagnostykę bez administratora. Sprawdź, że widoczne są urządzenia oraz stan usług, a same ustawienia Windows nie uległy zmianie.
2. Przy uruchomionym GG i Sonar porównaj listę, domyślne wyjście i wyciszenie z ustawieniami Windows. Powtórz z odłączonym odbiornikiem oraz z zamkniętym GG.
3. Wybierz fizyczne słuchawki, przetestuj odtwarzanie dźwięku i przywrócenie poprzednich ustawień. Powtórz z kanałem Sonar Gaming; w GG ręcznie wskaż prawidłowe słuchawki jako wyjście kanału. Sprawdź oddzielne urządzenie komunikacyjne i aplikację z własnym wyborem wyjścia.
4. Sprawdź opcję głośności i wyciszenia przy bezpiecznej głośności, a następnie przywracanie. Testuj też brak urządzenia, które zapisano w kopii.
5. W kontrolowanym środowisku sprawdź działanie na zatrzymanej usłudze audio, brak uprawnień administratora i obsługę błędu. Nie zatrzymuj usług na komputerze wykonującym ważne zadania.
6. Sprawdź polski tekst w konsoli, ścieżkę z odstępami, brak dostępu do folderu raportów, kilkukrotne uruchomienie oraz zachowanie po ponownym podłączeniu odbiornika.
7. Zanotuj wynik testu rzeczywistego odsłuchu, mikrofonu i komunikacji w grze lub Discordzie. Samo prawidłowe ustawienie urządzenia nie dowodzi, że użytkownik słyszy dźwięk.
