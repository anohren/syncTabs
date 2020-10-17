
import Foundation
import Darwin

func printError(_ string: String) {
    fputs("\(string)\n", stderr)
}

final class JCDefaults: NSObject {
    static let sharedInstance = JCDefaults()
    private let defaults = UserDefaults(suiteName: "codes.jorgecohen.syncTabs")!
    
    func tabSyncUUIDString() -> String {
        let tabSyncUUIDString = defaults.string(forKey: "tabSyncUUID") ?? UUID().uuidString
        defaults.set(tabSyncUUIDString, forKey: "tabSyncUUID")
        return tabSyncUUIDString
    }
    
    func deviceName() -> String {
        let deviceName = defaults.string(forKey: "deviceName") ?? "\(Host.current().localizedName ?? "Anonymous Device") Firefox"
        defaults.set(deviceName, forKey:"deviceName")
        return deviceName
    }
}

@objc
protocol WBSSafariBookmarksSyncAgentProtocol {
    func saveTabsForCurrentDeviceWithDictionaryRepresentation(_: NSDictionary, deviceUUIDString: NSString, completionHandler: @escaping (NSError)->())
}

class JCSyncThing : NSObject {
    private let connection: NSXPCConnection = {
        let conn = NSXPCConnection(machServiceName: "com.apple.SafariBookmarksSyncAgent", options: .init(rawValue: 0))
        conn.remoteObjectInterface = NSXPCInterface(with: WBSSafariBookmarksSyncAgentProtocol.self)
        conn.resume()
        return conn
    }()
    
    func saveTabs(_ tabs: NSArray, completionHandler: @escaping (NSError)->()) {
        let dict: NSDictionary // all values must be NSSecureCoding
            = [
                "Capabilities": [
                    "CloseTabRequest" : NSNumber(booleanLiteral: true),
                    "CloudKitBookmarkSyncing" : NSNumber(booleanLiteral: true)
                    ] as NSDictionary,
                "DeviceName" : JCDefaults.sharedInstance.deviceName() as NSString,
                "DictionaryType" : "Device" as NSString,
                "LastModified" : Date() as NSDate,
                "Tabs" : tabs
        ]
        
        (self.connection.remoteObjectProxy as! WBSSafariBookmarksSyncAgentProtocol).saveTabsForCurrentDeviceWithDictionaryRepresentation(dict, deviceUUIDString: JCDefaults.sharedInstance.deviceName() as NSString, completionHandler: completionHandler)
    }
}

let sync = JCSyncThing()
let stdin = FileHandle.standardInput

// Firefox send length of message first
stdin.readData(ofLength: 4)

// The rest is tabs data
let inputData = stdin.readDataToEndOfFile()
let json = try! JSONSerialization.jsonObject(with: inputData, options: .allowFragments)
let tabs = json as! NSArray
sync.saveTabs(tabs) { error in
    printError("saveTabs error: \(error.localizedDescription)")
}
