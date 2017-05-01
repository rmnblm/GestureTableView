import UIKit

class ViewController: UITableViewController {

    var data = [
        ("🍎", "Apple"), ("🍐", "Pear"), ("🍍", "Pineapple"), ("🍓", "Strawberry"),
        ("🍇", "Grape"), ("🍉", "Watermelon"), ("🍌", "Banana"), ("🥝", "Kiwi")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}

extension ViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FruitCell", for: indexPath)
        cell.textLabel?.text = data[indexPath.row].0
        cell.detailTextLabel?.text = data[indexPath.row].1
        return cell
    }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let item = data.remove(at: sourceIndexPath.row)
        data.insert(item, at: destinationIndexPath.row)
    }
}

extension ViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
}
