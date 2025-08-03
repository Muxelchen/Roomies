# HouseHero - Minimale To-Do Liste (Performance + Testing)

## 🎯 **NUR ESSENTIALS - App muss laufen, das war's**

---

## 🚨 **KRITISCH - Muss funktionieren**

### 1. **Basic Tests** (2 Tage)
- [ ] `AuthenticationManagerTests.swift` - Login/Logout funktioniert
- [ ] `PersistenceControllerTests.swift` - Core Data crasht nicht
- [ ] `TasksViewTests.swift` - Aufgaben erstellen/löschen funktioniert
- [ ] **Ziel: App crasht nicht bei normaler Nutzung**

### 2. **Performance Fixes** (1 Tag)  
- [ ] **Memory Leaks beheben**
  - [ ] Core Data Context richtig verwalten
  - [ ] Views richtig deallocieren
  - [ ] @Published Memory Cycles beheben

- [ ] **App Launch**
  - [ ] Unter 3 Sekunden starten
  - [ ] Keine Crashes beim Start

### 3. **Critical Bug Fixes** (1 Tag)
- [ ] **Crashes beheben**
  - [ ] Core Data save errors abfangen
  - [ ] View State crashes (SwiftUI)
  - [ ] Navigation crashes

---

## ✅ **Definition of Done**

- [ ] App startet ohne Crash
- [ ] Login/Logout funktioniert
- [ ] Aufgaben erstellen/bearbeiten funktioniert  
- [ ] Keine Memory Leaks bei 10min Nutzung
- [ ] Tests laufen grün durch

---

**🎯 Fazit:** 4 Tage Arbeit = Stabile, funktionierende App

**Alles andere kommt später!**