import CoreData

extension NSManagedObject {
    /// Sets a value for a Core Data key only if the attribute exists on the entity
    func setIfHasAttribute(_ value: Any?, forKey key: String) {
        if self.entity.attributesByName[key] != nil {
            self.setValue(value, forKey: key)
        }
    }

    /// Reads a Bool value for a Core Data key if it exists
    func boolIfHasAttribute(forKey key: String) -> Bool? {
        guard self.entity.attributesByName[key] != nil else { return nil }
        return self.value(forKey: key) as? Bool
    }

    /// Reads a String value for a Core Data key if it exists
    func stringIfHasAttribute(forKey key: String) -> String? {
        guard self.entity.attributesByName[key] != nil else { return nil }
        return self.value(forKey: key) as? String
    }

    /// Reads a Date value for a Core Data key if it exists
    func dateIfHasAttribute(forKey key: String) -> Date? {
        guard self.entity.attributesByName[key] != nil else { return nil }
        return self.value(forKey: key) as? Date
    }
}

extension NSEntityDescription {
    static func entity(_ name: String, in context: NSManagedObjectContext) -> NSEntityDescription? {
        return NSEntityDescription.entity(forEntityName: name, in: context)
    }
}



