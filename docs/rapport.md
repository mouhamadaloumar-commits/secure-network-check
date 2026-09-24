# Secure Network Check

## 1. Inledning

I den här uppgiften har jag gjort ett enkelt kontrollverktyg i Bash för Linux.
Målet är att kontrollera några viktiga saker i mitt nätverk och mitt system. Jag kontrollerar bland annat IP-adress, routing, DNS, portar och en lokal tjänst.

Jag har använt Ubuntu i WSL på min Windows-dator.
Jag har bara testat min egen Linux-miljö och localhost. Jag har inte skannat andra datorer eller nätverk och jag har inte ändrat brandvägg eller SSH.

## 2. Min miljö

Jag använder Ubuntu 26.04.1 LTS. Det körs i WSL på min Windows-dator. Mitt nätverkskort heter eth0. Det är kortet som kopplar min dator till nätverket. Min privata IP-adress är 172.21.109.103. Jag har också ett kort som heter lo. Det är ett låtsas-kort som bara pratar med min egen dator. Det kallas localhost och har adressen 127.0.0.1. Min default gateway är 172.21.96.1. Det är som en dörr ut. All trafik som ska lämna min dator går genom den dörren. WSL har ett eget nätverk inuti Windows. Det är därför nätverket ser lite annorlunda ut jämfört med en vanlig Linux-dator eller en server på internet, till exempel i OCI. Jag har bara kollat på min egen dator och localhost. Jag har inte kollat på andra datorer.

## 3. Manuella kontroller

### 3.1 Interface och IP-adress

Jag använde kommandot `ip address`. Mitt kort eth0 har adressen 172.21.109.103. Kortet lo är för localhost, adress 127.0.0.1. Bevis: Bild 1.

### 3.2 Routing

Jag använde kommandot `ip route`. Min default gateway är 172.21.96.1. Den skickar trafik ut från min dator. Bevis: Bild 2.

### 3.3 DNS

Jag använde kommandot `getent hosts example.com`. Uppslaget fungerade, example.com hittades. Bevis: Bild 3.

### 3.4 Lyssnande portar

Jag använde kommandot `ss -tuln`. Jag såg DNS-portar och en lokal UDP-port. Ingen SSH- eller HTTP-port syntes i den manuella kontrollen. Bevis: Bild 4.

### 3.5 Processer

Jag använde kommandot `ps -ef | head`. Det visade flera processer som körs i min Linux-miljö. Bevis: Bild 5.

### 3.6 Lokal tjänst

Jag kontrollerade en lokal testtjänst på localhost. Skriptet startar en tillfällig webbserver på port 8080 och kontrollerar sedan att tjänsten svarar. Testtjänsten används bara lokalt och stoppas efter testet. Bevis: Bild 6.

## 4. Skriptet

Jag har gjort skriptet `scripts/secure_network_check.sh`. Skriptet kontrollerar min egen Linux-miljö på ett säkert sätt.

Skriptet kontrollerar nätverkskort och IP-adress, default gateway, DNS, en lokal testtjänst, localhost på port 8080, lyssnande portar och processer.

Skriptet använder funktioner för de olika kontrollerna. Det använder också en lista och en loop för att köra kontrollerna.

Skriptet skriver resultat med statusen INFO, OK, WARN eller FAIL.

Skriptet skapar också en loggfil med datum och tid.

En lokal testtjänst startas på localhost port 8080. När kontrollen är klar stoppas tjänsten och den tillfälliga testkatalogen tas bort.

Skriptet använder exitkoder för att visa om kontrollerna lyckades eller misslyckades.

Jag använder inte sudo för hela skriptet. Jag gör inga ändringar i brandväggen eller SSH.

### 4.1 Test av skriptet normalfall

Jag körde skriptet i min Ubuntu-miljö.

**Normalfall 1 – DNS**

Jag testade DNS med example.com.

Förväntat resultat: DNS-uppslaget ska lyckas.

Verkligt resultat: DNS-uppslaget lyckades och kontrollen visade OK.

Resultat: Testet fungerade som förväntat.

**Normalfall 2 – lokal testtjänst**

Skriptet startade en lokal testtjänst på localhost port 8080.

Förväntat resultat: Den lokala testtjänsten ska svara.

Verkligt resultat: Testet med localhost fungerade och port 8080 lyssnade lokalt.

Resultat: Testet fungerade som förväntat.

I samma körning lyckades totalt 6 kontroller och 0 kontroller misslyckades. Efter testet stoppades den lokala testtjänsten och den tillfälliga testkatalogen togs bort.

Bevis: Bild 6 – Skript normalfall.

### 4.2 Test av skriptet felfall port

Jag testade en port där ingen tjänst kördes.

Jag använde port 8099 eftersom min lokala testtjänst använder port 8080.

Förväntat resultat: Anslutningen ska misslyckas eftersom ingen tjänst lyssnar på port 8099.

Verkligt resultat: Anslutningen misslyckades och curl visade att den inte kunde ansluta till port 8099. Resultatet var `Connection refused`.

Resultat: Testet fungerade som förväntat. Port 8099 hade ingen tjänst som lyssnade.

Bevis: Bild 3 – Felfall port.

### 4.3 Test av skriptet felfall DNS

Jag testade ett DNS-namn som inte finns.

Jag använde namnet `does-not-exist-123456789.example`.

Förväntat resultat: DNS-uppslaget ska misslyckas eftersom namnet inte finns.

Verkligt resultat: DNS-uppslaget misslyckades och kontrollen visade WARN. I testkörningen lyckades 5 kontroller och 1 kontroll misslyckades.

Resultat: Testet fungerade som förväntat. Kontrollen kunde upptäcka att DNS-uppslaget misslyckades utan att skriptet kraschade okontrollerat.

Bevis: Bild 2 – Felfall DNS.

### 4.4 Sammanfattning av tester

Jag gjorde två tester där allt fungerade och två tester där jag testade fel.

DNS-testet med example.com fungerade.

Testet av den lokala tjänsten på port 8080 fungerade.

Testet mot port 8099 misslyckades eftersom ingen tjänst kördes där. Det var ett förväntat fel.

DNS-testet med ett namn som inte finns misslyckades. Kontrollen visade WARN vilket var förväntat.

Testerna visar att kontrollerna kan upptäcka både fungerande och felaktiga situationer. Den lokala testtjänsten stoppas efter testet och testporten ligger därför inte kvar och lyssnar efter testet.

## 5. Hardening och säkerhet

Jag kontrollerade vilka portar som lyssnade i min Linux-miljö.

I den manuella kontrollen såg jag framför allt DNS-relaterade portar och en lokal UDP-port. Jag såg ingen SSH- eller HTTP-port i den manuella kontrollen.

En tjänst som behöver finnas kvar är DNS-tjänsten eftersom Linux behöver DNS för att kunna översätta domännamn till IP-adresser.

Jag har inte stängt av någon tjänst eller ändrat brandvägg eftersom uppgiften ska genomföras säkert i min egen WSL-miljö.

Efter mina tester stoppas den lokala testtjänsten på port 8080. Detta gör att testporten inte ligger kvar och lyssnar efter testet.

## 6. Backup och återställning

Om systemet skulle behöva återställas är det viktigt att kontrollera nätverket efteråt.

Den första kontrollen jag skulle göra är `ip address`. Den visar om nätverkskortet och IP-adressen finns kvar.

Den andra kontrollen är `ip route`. Den visar om det finns en default gateway och om routing fungerar.

Dessa två kontroller kan visa om nätverksinställningarna fungerar efter en återställning.

## 7. CIA säkerhetens tre delar

### 7.1 Confidentiality sekretess

Nätverksinformation som IP-adresser och portar kan vara känslig. Jag delar bara det som behövs i rapporten.

### 7.2 Integrity riktighet

Resultat ska inte ändras utan att man märker det. Skriptet sparar resultaten i en loggfil med datum och tid. Tydliga statusar som INFO, OK, WARN och FAIL gör det lättare att tolka resultatet.

### 7.3 Availability tillgänglighet

Nätverket och tjänsterna ska fungera när de behövs. Mina kontroller av DNS, routing, portar och den lokala tjänsten visar om funktionerna är tillgängliga.

### 7.4 Exempel på avvägning

Mer loggning gör felsökning enklare men kan visa känslig information. Därför sparar jag bara det som behövs.

## 8. Reflektion

Den kontroll som jag tycker är mest användbar är kontrollen av lyssnande portar. Den visar vilka portar som används och kan hjälpa till att hitta tjänster som inte ska vara öppna.

Den största skillnaden mot en vanlig Linux-server är att jag använder WSL. WSL kör Linux inuti Windows och har därför ett virtuellt nätverk.

Det svåraste för mig var att förstå hur routing, IP-adresser och portar fungerar tillsammans. Jag fick också lära mig hur Bash-funktioner och loggning fungerar.

I en version 2 skulle jag kunna lägga till fler kontroller och göra rapporteringen ännu tydligare.

I verkligheten ska ett sådant verktyg bara användas på system som man själv äger eller har tillstånd att kontrollera. Man ska inte skanna andra datorer utan tillstånd.

## 9. AI-användning

Jag tog hjälp av ChatGPT för att förstå uppgiften och hitta vissa Linux-kommandon. Jag använde förslag som stöd för Bash-skriptet och kontrollerade sedan funktionerna genom att köra skriptet själv i min WSL-miljö.

Jag testade själv normalfall och felfall och kontrollerade att loggning, statusar, exitbeteende och cleanup fungerade.
