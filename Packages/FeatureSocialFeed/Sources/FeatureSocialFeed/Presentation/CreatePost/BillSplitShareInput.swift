import Foundation

struct BillSplitShareSnapshot {
    var texts: [UUID: String]
    var explicitIds: Set<UUID>
}

/// Caps % (0...100) and exact VND (0...total). The remaining unentered person gets the leftover.
enum BillSplitShareInput {
    private static let hundred = Decimal(100)
    private static let zero = Decimal(0)

    static func sanitizePercentInput(_ raw: String) -> String {
        var out = ""
        var hasSeparator = false
        for character in raw {
            if character.isNumber {
                out.append(character)
            } else if (character == "." || character == ",") && !hasSeparator {
                out.append(character)
                hasSeparator = true
            }
        }
        guard let value = VNDMoneyFormat.parsePercent(out) else { return out }
        if value > hundred { return formatPercent(hundred) }
        if value < zero { return formatPercent(zero) }
        return out
    }

    static func applyPercent(
        editedId: UUID,
        raw: String,
        orderedIds: [UUID],
        current: [UUID: String],
        explicitIds: Set<UUID>
    ) -> BillSplitShareSnapshot {
        var texts = current
        var explicit = explicitIds.intersection(Set(orderedIds))
        let sanitized = sanitizePercentInput(raw)
        let parsed = VNDMoneyFormat.parsePercent(sanitized)

        if parsed == nil {
            explicit.remove(editedId)
            texts[editedId] = sanitized
            return rebalancePercent(orderedIds: orderedIds, current: texts, explicitIds: explicit)
        }

        var value = min(max(parsed ?? zero, zero), hundred)
        if value >= hundred {
            texts[editedId] = formatPercent(hundred)
            for id in orderedIds where id != editedId {
                texts[id] = formatPercent(zero)
            }
            return BillSplitShareSnapshot(texts: texts, explicitIds: [editedId])
        }

        let others = sumPercent(ids: explicit.filter { $0 != editedId }, texts: texts)
        let maxThis = max(zero, hundred - others)
        if value > maxThis {
            value = maxThis
            texts[editedId] = formatPercent(value)
        } else {
            texts[editedId] = sanitized
        }
        explicit.insert(editedId)
        return rebalancePercent(orderedIds: orderedIds, current: texts, explicitIds: explicit)
    }

    static func rebalancePercent(
        orderedIds: [UUID],
        current: [UUID: String],
        explicitIds: Set<UUID>
    ) -> BillSplitShareSnapshot {
        var texts = current
        let explicit = explicitIds.intersection(Set(orderedIds))
        if orderedIds.count == 1, let only = orderedIds.first {
            texts[only] = formatPercent(hundred)
            return BillSplitShareSnapshot(texts: texts, explicitIds: [])
        }

        let implicitIds = orderedIds.filter { !explicit.contains($0) }
        let remainder = min(hundred, max(zero, hundred - sumPercent(ids: explicit, texts: texts)))
        if implicitIds.count == 1, let remainingId = implicitIds.first {
            texts[remainingId] = formatPercent(remainder)
        } else if remainder <= zero {
            for id in implicitIds {
                texts[id] = formatPercent(zero)
            }
        } else {
            for id in implicitIds {
                texts[id] = ""
            }
        }
        return BillSplitShareSnapshot(texts: texts, explicitIds: explicit)
    }

    static func applyExact(
        editedId: UUID,
        raw: String,
        orderedIds: [UUID],
        current: [UUID: String],
        explicitIds: Set<UUID>,
        total: Decimal?
    ) -> BillSplitShareSnapshot {
        var texts = current
        var explicit = explicitIds.intersection(Set(orderedIds))
        let sanitized = VNDMoneyFormat.sanitizedInput(from: raw)
        guard let total else {
            if sanitized.isEmpty {
                explicit.remove(editedId)
            } else {
                explicit.insert(editedId)
            }
            texts[editedId] = sanitized
            return BillSplitShareSnapshot(texts: texts, explicitIds: explicit)
        }
        let parsed = VNDMoneyFormat.parse(sanitized)

        if parsed == nil {
            explicit.remove(editedId)
            texts[editedId] = sanitized
            return rebalanceExact(orderedIds: orderedIds, current: texts, explicitIds: explicit, total: total)
        }

        var value = min(max(parsed ?? zero, zero), total)
        if value >= total {
            texts[editedId] = VNDMoneyFormat.format(total)
            for id in orderedIds where id != editedId {
                texts[id] = VNDMoneyFormat.format(zero)
            }
            return BillSplitShareSnapshot(texts: texts, explicitIds: [editedId])
        }

        let others = sumExact(ids: explicit.filter { $0 != editedId }, texts: texts)
        let maxThis = max(zero, total - others)
        if value > maxThis {
            value = maxThis
            texts[editedId] = VNDMoneyFormat.format(value)
        } else {
            texts[editedId] = sanitized
        }
        explicit.insert(editedId)
        return rebalanceExact(orderedIds: orderedIds, current: texts, explicitIds: explicit, total: total)
    }

    static func rebalanceExact(
        orderedIds: [UUID],
        current: [UUID: String],
        explicitIds: Set<UUID>,
        total: Decimal?
    ) -> BillSplitShareSnapshot {
        var texts = current
        let explicit = explicitIds.intersection(Set(orderedIds))
        guard let total else {
            return BillSplitShareSnapshot(texts: texts, explicitIds: explicit)
        }
        if orderedIds.count == 1, let only = orderedIds.first {
            texts[only] = VNDMoneyFormat.format(max(zero, total))
            return BillSplitShareSnapshot(texts: texts, explicitIds: [])
        }

        let implicitIds = orderedIds.filter { !explicit.contains($0) }
        let remainder = min(total, max(zero, total - sumExact(ids: explicit, texts: texts)))
        if implicitIds.count == 1, let remainingId = implicitIds.first {
            texts[remainingId] = VNDMoneyFormat.format(remainder)
        } else if remainder <= zero {
            for id in implicitIds {
                texts[id] = VNDMoneyFormat.format(zero)
            }
        } else {
            for id in implicitIds {
                texts[id] = ""
            }
        }
        return BillSplitShareSnapshot(texts: texts, explicitIds: explicit)
    }

    static func formatPercent(_ value: Decimal) -> String {
        let clamped = min(hundred, max(zero, value))
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 4
        return formatter.string(from: clamped as NSDecimalNumber) ?? "0"
    }

    private static func sumPercent<S: Sequence>(ids: S, texts: [UUID: String]) -> Decimal
        where S.Element == UUID {
        ids.reduce(zero) { partial, id in
            partial + (VNDMoneyFormat.parsePercent(texts[id] ?? "") ?? zero)
        }
    }

    private static func sumExact<S: Sequence>(ids: S, texts: [UUID: String]) -> Decimal
        where S.Element == UUID {
        ids.reduce(zero) { partial, id in
            partial + (VNDMoneyFormat.parse(texts[id] ?? "") ?? zero)
        }
    }
}
