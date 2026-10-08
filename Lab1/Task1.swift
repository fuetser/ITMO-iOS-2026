struct Order {
    let id: Int
    let customer: String
    let amount: Double
    let isPaid: Bool
    let promoCode: String?
}

let orders: [Order] = [
    Order(id: 1, customer: "Анна", amount: 1200, isPaid: true, promoCode: "SALE10"),
    Order(id: 2, customer: "Иван", amount: 800, isPaid: false, promoCode: nil),
    Order(id: 3, customer: "Анна", amount: 5400, isPaid: true, promoCode: nil),
    Order(id: 4, customer: "Олег", amount: 300, isPaid: true, promoCode: "NEW"),
    Order(id: 5, customer: "Иван", amount: 2100, isPaid: false, promoCode: "SALE10")
]

// Суммы оплаченных заказов
let paidAmounts = orders.filter { $0.isPaid }.map { $0.amount }

// Общая сумма неоплаченных заказов
let unpaidTotal = orders
    .filter { !$0.isPaid }
    .reduce(0.0) { $0 + $1.amount }

// Уникальные имена клиентов в алфавитном порядке
let uniqueCustomers = Array(Set(orders.map { $0.customer })).sorted()

// Промокоды без nil
let promoCodes = orders.compactMap { $0.promoCode }

// Заказы, сгруппированные по клиенту
let ordersByCustomer = Dictionary(grouping: orders, by: { $0.customer })

// Клиент с максимальной суммой оплаченных заказов
let paidTotalsByCustomer = Dictionary(grouping: orders.filter { $0.isPaid }, by: { $0.customer })
    .mapValues { customerOrders in customerOrders.reduce(0.0) { $0 + $1.amount } }
let topPaidCustomer = paidTotalsByCustomer.max { $0.value < $1.value }

print("Суммы оплаченных заказов: \(paidAmounts)")
print("Сумма неоплаченных заказов: \(unpaidTotal)")
print("Клиенты: \(uniqueCustomers)")
print("Промокоды: \(promoCodes)")
print("Заказы по клиентам: \(ordersByCustomer)")
if let topPaidCustomer {
    print("Максимальная оплаченная сумма: \(topPaidCustomer.key) — \(topPaidCustomer.value)")
}
