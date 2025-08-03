# 🏗️ NSManagedObjectContext Architektur-Strategie

## 🎯 **ZIEL: Fehlerfreie, skalierbare Core Data Architektur**

### **1. GOLDENE REGELN (NIEMALS VERLETZEN)**

#### **A) Context-Typen niemals verwechseln**
```swift
// ✅ RICHTIG: Klare Trennung
let coreDataContext = viewContext              // Für Datenbank
let biometricContext = LAContext()            // Für Authentifizierung

// ❌ FALSCH: Verwechslung führt zu Compiler-Fehlern
// SomeEntity(context: LAContext())           // NICHT MÖGLICH!
```

#### **B) Environment Pattern in Views**
```swift
// ✅ RICHTIG: Jede View verwendet Environment
struct MyView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    private func saveData() {
        let entity = MyEntity(context: viewContext)  // ✅ KORREKT
        try? viewContext.save()
    }
}
```

#### **C) Manager verwalten eigene Contexts**
```swift
// ✅ RICHTIG: Manager erstellt eigene Background Contexts
class MyManager {
    func backgroundOperation() {
        let context = PersistenceController.shared.newBackgroundContext()
        context.perform {
            // Arbeit mit context
        }
    }
}
```

### **2. FEHLER-LOOP VERMEIDUNGSMATRIX**

| ❌ **FEHLERHAFTE MUSTER** | ✅ **KORREKTE MUSTER** |
|-------------------------|----------------------|
| `func process(_ closure: @escaping () -> NSManagedObjectContext)` | `func process(context: NSManagedObjectContext)` |
| `MyView(context: { return viewContext })` | `MyView().environment(\.managedObjectContext, viewContext)` |
| `SomeEntity(context: LAContext())` | `SomeEntity(context: viewContext)` |
| Context zwischen Threads teilen | Jeden Thread eigenen Context geben |

### **3. COMPILER-ERROR DEBUGGING PROZESS**

#### **Schritt 1: Error Message dekodieren**
```
"trailing closure passed to parameter of type NSManagedObjectContext that does not accept a closure"

BEDEUTUNG: Sie übergeben { } statt einem direkten Context
```

#### **Schritt 2: Suche nach problematischen Patterns**
```bash
# Suchen Sie nach:
grep -r "context:" . --include="*.swift"
grep -r "LAContext" . --include="*.swift"
grep -r "@escaping.*NSManagedObjectContext" . --include="*.swift"
```

#### **Schritt 3: Systematische Korrektur**
1. **Views**: Alle müssen `@Environment(\.managedObjectContext)` verwenden
2. **Managers**: Eigene Contexts erstellen mit `newBackgroundContext()`
3. **Services**: Context als direkten Parameter erwarten

### **4. BAUBARE-PROJEKT CHECKLISTE**

#### **Pre-Build Check (vor jedem Build):**
- [ ] Alle Views haben `@Environment(\.managedObjectContext) private var viewContext`
- [ ] Keine `LAContext` wo `NSManagedObjectContext` erwartet wird
- [ ] Manager-Funktionen haben `context: NSManagedObjectContext` Parameter
- [ ] Keine trailing closures bei Context-Parametern

#### **Post-Error Recovery:**
1. **Identifiziere den fehlerhaften View/Manager**
2. **Prüfe Context-Typ (LA vs NSManaged)**
3. **Wende Goldene Regeln an**
4. **Teste mit Minimalbeispiel**

### **5. TEAM-ENTWICKLUNG GUIDELINES**

#### **Code Review Checklist:**
```swift
// ❌ ABLEHNEN bei:
- LAContext in Core Data Operations
- Trailing closures für Contexts
- Context-Sharing zwischen Threads
- Missing @Environment in Views

// ✅ AKZEPTIEREN bei:
- Environment Pattern
- Direct Context Parameters
- Background Context Creation
- Clear Context Ownership
```

#### **Naming Conventions:**
```swift
// ✅ KLAR: Typ ist erkennbar
let coreDataContext: NSManagedObjectContext
let authContext: LAContext
let backgroundContext: NSManagedObjectContext

// ❌ VERWIRREND: Typ unklar
let context        // Welcher Typ?
let ctx           // Abkürzung unverständlich
```

### **6. EMERGENCY RECOVERY PLAN**

#### **Bei kompletter Fehler-Schleife:**

1. **STOPP**: Keine weiteren Änderungen
2. **BACKUP**: Git commit current state
3. **MINIMAL**: Kopiere das Minimalbeispiel
4. **REBUILD**: Feature für Feature migrieren
5. **TEST**: Nach jedem Feature kompilieren

#### **Schrittweise Migration:**
```
Tag 1: PersistenceController + 1 View
Tag 2: + 1 Manager (z.B. AuthenticationManager)
Tag 3: + 1 Service (z.B. NotificationManager)
...
Tag N: Komplettes Projekt funktional
```

### **7. LANGFRISTIGE ARCHITEKTUR**

#### **Skalierbare Struktur:**
```
HouseholdApp/
├── CoreData/
│   ├── PersistenceController.swift     # Single Source of Truth
│   ├── CoreDataExtensions.swift       # Helper Extensions
│   └── Models/                         # Generated Classes
├── Views/
│   └── *.swift                        # Alle mit @Environment
├── Managers/
│   └── *.swift                        # Eigene Background Contexts
└── Services/
    └── *.swift                        # Context als Parameter
```

#### **Testing Strategy:**
```swift
// Unit Tests für Context Management
func testContextPatterns() {
    let context = PersistenceController.preview.container.viewContext
    
    // Test View Environment
    let view = MyView().environment(\.managedObjectContext, context)
    
    // Test Manager Operations  
    let manager = MyManager()
    manager.process(context: context)
    
    // Assertions...
}
```

## 🚀 **SOFORT-AKTIONEN FÜR IHR PROJEKT**

1. **Kopieren Sie das Minimalbeispiel** in ein neues Xcode-Projekt
2. **Testen Sie, dass es kompiliert** 
3. **Migrieren Sie schrittweise** Ihre Features
4. **Verwenden Sie die CoreDataArchitectureGuide.swift** als Referenz
5. **Implementieren Sie die Emergency Recovery** bei Problemen

## ⚡ **ERFOLGS-METRIKEN**

- **100% Build Success Rate**: Projekt kompiliert immer
- **0 Context-Type Verwechslungen**: Klare Trennung LA/Core Data
- **Einheitliche Patterns**: Alle Views/Managers folgen Standards
- **Fehler-Resistenz**: Team kann sicher entwickeln ohne Loops