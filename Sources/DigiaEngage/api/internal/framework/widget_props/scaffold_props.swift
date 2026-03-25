import Foundation

struct ScaffoldProps: Codable, Equatable, Sendable {
    var scaffoldBackgroundColor: ExprOr<String>? = nil
    var enableSafeArea: ExprOr<Bool>? = nil
    var resizeToAvoidBottomInset: ExprOr<Bool>? = nil
    var body: String? = nil
    var appBar: String? = nil
    var drawer: String? = nil
    var endDrawer: String? = nil
    var bottomNavigationBar: String? = nil
    var persistentFooterButtons: [String]? = nil
}
