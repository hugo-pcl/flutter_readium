import ReadiumNavigator

let blackAndWhiteComicModeKey: String = "blackAndWhiteComicMode";
let disableSynchronizationKey: String = "disableSynchronization";
let firstElementTopMarginKey: String = "firstElementTopMargin";
let lastElementBottomMarginKey: String = "lastElementBottomMargin";
let preventMOColumnBreaksKey: String = "preventMOColumnBreaks";
let autoAdvanceChaptersKey: String = "autoAdvanceChapters";

let topMarginCssVariable = "--FLUTTER_READIUM-first-element-top-margin"
let bottomMarginCssVariable = "--FLUTTER_READIUM-last-element-bottom-margin";
let blackAndWhiteComicModeCssVariable = "--FLUTTER_READIUM-black-white-comic-mode";

public struct FlutterEPUBPreferences {
  
  /// Base preferences for Readium Navigator.
  public var readium: EPUBPreferences = EPUBPreferences.init();
  /// B&W modification for comics.
  public var blackAndWhiteComicMode: Bool?
  /// Flag to switch off automatic sync from audio position to visual reader.
  public var disableSync: Bool?
  /// Top margin to the first element in the content.
  /// This is used to create space for UI elements like a toolbar without overlapping the content.
  public var firstElementTopMargin: Int?
  /// Margin applied to the bottom of the last element in the content.
  /// This creates breathing room at the end of the scroll.
  public var lastElementBottomMargin: Int?
  /// When true (default), prevents paragraph elements from splitting across CSS columns during
  /// media-overlay playback. Nil means the Dart-side default (true) applies.
  public var preventMOColumnBreaks: Bool?
  /// When true and scroll is also enabled, automatically advances to the next/previous
  /// chapter when scrolling reaches the end/start of the current resource.
  public var autoAdvanceChapters: Bool?

  init() {
    readium = EPUBPreferences.init();
  }

  init(fromMap jsonMap: Dictionary<String, Any>) {
    var mutableMap = jsonMap
    /// Process our extension preferences and remove them from the map
    if let blackAndWhite = jsonMap[blackAndWhiteComicModeKey] as? Bool {
      self.blackAndWhiteComicMode = blackAndWhite
      mutableMap.removeValue(forKey: blackAndWhiteComicModeKey);
    }
    if let disableSync = jsonMap[disableSynchronizationKey] as? Bool {
      self.disableSync = disableSync
      mutableMap.removeValue(forKey: disableSynchronizationKey);
    }
    if let firstElementTopMargin = jsonMap[firstElementTopMarginKey] as? Int {
      self.firstElementTopMargin = firstElementTopMargin
      mutableMap.removeValue(forKey: firstElementTopMarginKey);
    }
    if let lastElementBottomMargin = jsonMap[lastElementBottomMarginKey] as? Int {
      self.lastElementBottomMargin = lastElementBottomMargin
      mutableMap.removeValue(forKey: lastElementBottomMarginKey);
    }
    if let preventMOColumnBreaks = jsonMap[preventMOColumnBreaksKey] as? Bool {
      self.preventMOColumnBreaks = preventMOColumnBreaks
      mutableMap.removeValue(forKey: preventMOColumnBreaksKey);
    }
    if let autoAdvanceChapters = jsonMap[autoAdvanceChaptersKey] as? Bool {
      self.autoAdvanceChapters = autoAdvanceChapters
      mutableMap.removeValue(forKey: autoAdvanceChaptersKey);
    }

    readium = EPUBPreferences.init(fromMap: mutableMap)
  }
  
  func toCustomCssVariables() -> [String: String?] {
      var map: [String: String?] = [:]

      map[topMarginCssVariable] = firstElementTopMargin.map { "\($0)px" }
      map[bottomMarginCssVariable] = lastElementBottomMargin.map { "\($0)px" }
      map[blackAndWhiteComicModeCssVariable] = (blackAndWhiteComicMode == true) ? "1" : nil

      return map
  }

  func toInjectableStyleSheet() -> String {
      let cssVariables = toCustomCssVariables()
          .compactMap { key, value -> String? in
              guard let value else { return nil }
              return "\(key): \(value) !important"
          }
          .joined(separator: ";")

      return """
      :root {\(cssVariables)}
      """
  }
}
