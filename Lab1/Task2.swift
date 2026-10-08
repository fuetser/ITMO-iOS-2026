struct Point: Hashable {
    var x: Double
    var y: Double

    mutating func move(byX dx: Double, byY dy: Double) {
        x += dx
        y += dy
    }

    var distanceToOrigin: Double {
        (x * x + y * y).squareRoot()
    }
}

struct Rectangle {
    var origin: Point
    var width: Double
    var height: Double

    init(origin: Point, width: Double, height: Double) {
        self.origin = origin
        self.width = width > 0 ? width : 1.0
        self.height = height > 0 ? height : 1.0
    }

    var area: Double {
        width * height
    }

    var perimeter: Double {
        2 * (width + height)
    }

    var center: Point {
        Point(x: origin.x + width / 2, y: origin.y + height / 2)
    }

    mutating func scale(by factor: Double) {
        width *= factor
        height *= factor
    }

    func contains(_ point: Point) -> Bool {
        point.x >= origin.x && point.x <= origin.x + width &&
        point.y >= origin.y && point.y <= origin.y + height
    }
}

// Пример использования
var point = Point(x: 3, y: 4)
point.move(byX: 1, byY: -2)
print("Расстояние до начала координат: \(point.distanceToOrigin)")

var rectangle = Rectangle(origin: Point(x: 0, y: 0), width: 10, height: 5)
rectangle.scale(by: 2)
print("Площадь: \(rectangle.area), периметр: \(rectangle.perimeter)")
print("Центр: \(rectangle.center), содержит точку: \(rectangle.contains(point))")
