import UIKit

@MainActor
protocol ScreenAdHosting: AnyObject {
    func install(in controller: UIViewController)
    func appear()
    func disappear()
    func layout()
    func setEditing(_ editing: Bool)
}
