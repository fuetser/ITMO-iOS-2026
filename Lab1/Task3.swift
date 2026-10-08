/// Очередь с приоритетом на бинарной max-heap.
/// `hasHigherPriority(a, b)` должна возвращать true, если `a` выше `b`.
struct PriorityQueue<Element> {
    private var heap: [Element] = []
    private let hasHigherPriority: (Element, Element) -> Bool

    init(by hasHigherPriority: @escaping (Element, Element) -> Bool) {
        self.hasHigherPriority = hasHigherPriority
    }

    var isEmpty: Bool { heap.isEmpty }
    var count: Int { heap.count }
    var peek: Element? { heap.first }

    mutating func enqueue(_ element: Element) {
        heap.append(element)
        siftUp(from: heap.count - 1)
    }

    @discardableResult
    mutating func dequeue() -> Element? {
        guard !heap.isEmpty else { return nil }
        if heap.count == 1 { return heap.removeLast() }

        let result = heap[0]
        heap[0] = heap.removeLast()
        siftDown(from: 0)
        return result
    }

    private mutating func siftUp(from startIndex: Int) {
        var child = startIndex
        var parent = (child - 1) / 2

        while child > 0 && hasHigherPriority(heap[child], heap[parent]) {
            heap.swapAt(child, parent)
            child = parent
            parent = (child - 1) / 2
        }
    }

    private mutating func siftDown(from startIndex: Int) {
        var parent = startIndex

        while true {
            let left = 2 * parent + 1
            let right = left + 1
            var candidate = parent

            if left < heap.count && hasHigherPriority(heap[left], heap[candidate]) {
                candidate = left
            }
            if right < heap.count && hasHigherPriority(heap[right], heap[candidate]) {
                candidate = right
            }
            guard candidate != parent else { return }
            heap.swapAt(parent, candidate)
            parent = candidate
        }
    }
}

// Пример: извлечение чисел от большего к меньшему.
var queue = PriorityQueue<Int>(by: >)
queue.enqueue(4)
queue.enqueue(10)
queue.enqueue(2)
print(queue.dequeue() as Any) // Optional(10)
print(queue.dequeue() as Any) // Optional(4)
