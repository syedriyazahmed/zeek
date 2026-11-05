"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.cancelSale = exports.completeSale = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();
/**
 * Atomic sale transaction:
 * 1. Checks product existence and stock availability
 * 2. Deducts product stock atomically
 * 3. Creates Sale document
 * 4. Records Stock Movement documents (SALE)
 * 5. Records Account Ledger Entry (SALE_INCOME)
 * 6. Updates or creates Daily Summary
 */
exports.completeSale = functions.https.onCall(async (request) => {
    const data = request.data;
    const auth = request.auth;
    if (!auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be logged in.");
    }
    const shopId = data.shopId || "main_shop";
    const shopRef = db.collection("shops").doc(shopId);
    // Validate payment split
    const cash = Number(data.cashAmount) || 0;
    const online = Number(data.onlineAmount) || 0;
    const total = Number(data.grandTotal) || 0;
    if (Math.abs(cash + online - total) > 0.01) {
        throw new functions.https.HttpsError("invalid-argument", `Payment breakdown (Cash: ₹${cash}, Online: ₹${online}) does not equal Grand Total (₹${total}).`);
    }
    if (!data.items || data.items.length === 0) {
        throw new functions.https.HttpsError("invalid-argument", "Sale cart cannot be empty.");
    }
    const todayStr = new Date().toISOString().split("T")[0];
    const timestamp = admin.firestore.FieldValue.serverTimestamp();
    const invoiceNumber = `INV-${Date.now().toString().slice(-6)}`;
    const saleRef = shopRef.collection("sales").doc();
    const saleId = saleRef.id;
    // Execute atomic transaction
    await db.runTransaction(async (transaction) => {
        // 1. Read all product docs first
        const productDocs = [];
        for (const item of data.items) {
            const prodRef = shopRef.collection("products").doc(item.productId);
            const prodSnap = await transaction.get(prodRef);
            if (!prodSnap.exists) {
                throw new functions.https.HttpsError("not-found", `Product "${item.productName}" not found.`);
            }
            const prodData = prodSnap.data();
            const available = Number(prodData.availableQuantity) || 0;
            if (available < item.quantity) {
                throw new functions.https.HttpsError("failed-precondition", `Insufficient stock for "${prodData.productName}". Available: ${available} ${prodData.unit}, Requested: ${item.quantity} ${prodData.unit}.`);
            }
            productDocs.push({ ref: prodRef, data: prodData, item });
        }
        // Read daily summary doc
        const dailySummaryRef = shopRef.collection("daily_summaries").doc(todayStr);
        const dailySummarySnap = await transaction.get(dailySummaryRef);
        // 2. Perform writes: Deduct stock & create stock movements
        for (const { ref: prodRef, data: prodData, item } of productDocs) {
            const currentAvailable = Number(prodData.availableQuantity) || 0;
            const currentSold = Number(prodData.totalSold) || 0;
            const newAvailable = Math.round((currentAvailable - item.quantity) * 100) / 100;
            const newSold = Math.round((currentSold + item.quantity) * 100) / 100;
            transaction.update(prodRef, {
                availableQuantity: newAvailable,
                totalSold: newSold,
                updatedAt: timestamp,
            });
            // Record stock movement (negative for deduction)
            const movementRef = shopRef.collection("stock_movements").doc();
            transaction.set(movementRef, {
                movementId: movementRef.id,
                productId: item.productId,
                productName: item.productName,
                movementType: "SALE",
                quantity: -item.quantity,
                unit: item.unit,
                referenceId: saleId,
                date: todayStr,
                createdBy: auth.uid,
                createdAt: timestamp,
            });
        }
        // 3. Create Sale Document
        transaction.set(saleRef, {
            saleId,
            invoiceNumber,
            date: todayStr,
            timestamp,
            items: data.items,
            subtotal: data.subtotal,
            discount: data.discount || 0,
            grandTotal: total,
            paymentType: data.paymentType,
            cashAmount: cash,
            onlineAmount: online,
            customerName: data.customerName || null,
            customerPhone: data.customerPhone || null,
            status: "completed",
            createdBy: auth.uid,
            createdAt: timestamp,
        });
        // 4. Create Account Entry (SALE_INCOME)
        const accountEntryRef = shopRef.collection("account_entries").doc();
        transaction.set(accountEntryRef, {
            entryId: accountEntryRef.id,
            date: todayStr,
            transactionType: "SALE_INCOME",
            referenceId: saleId,
            cashAmount: cash,
            onlineAmount: online,
            description: `POS Sale #${invoiceNumber}`,
            status: "active",
            createdBy: auth.uid,
            createdAt: timestamp,
        });
        // 5. Update Daily Summary
        if (dailySummarySnap.exists) {
            const current = dailySummarySnap.data();
            transaction.update(dailySummaryRef, {
                cashSales: (Number(current.cashSales) || 0) + cash,
                onlineSales: (Number(current.onlineSales) || 0) + online,
                totalSales: (Number(current.totalSales) || 0) + total,
                totalTransactions: (Number(current.totalTransactions) || 0) + 1,
                closingCashBalance: (Number(current.closingCashBalance) || 0) + cash,
                closingOnlineBalance: (Number(current.closingOnlineBalance) || 0) + online,
            });
        }
        else {
            transaction.set(dailySummaryRef, {
                date: todayStr,
                cashSales: cash,
                onlineSales: online,
                totalSales: total,
                totalTransactions: 1,
                cashExpenses: 0,
                onlineExpenses: 0,
                totalExpenses: 0,
                cashOpeningBalance: 0,
                onlineOpeningBalance: 0,
                cashToBankTransfers: 0,
                closingCashBalance: cash,
                closingOnlineBalance: online,
            });
        }
    });
    return {
        success: true,
        saleId,
        invoiceNumber,
        message: "Sale processed successfully.",
    };
});
/**
 * Cancel/Void Sale Transaction:
 * Restores inventory stock, adds reversal movement, adds reversal account entry,
 * and marks sale cancelled.
 */
exports.cancelSale = functions.https.onCall(async (request) => {
    const data = request.data;
    const auth = request.auth;
    if (!auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
    }
    const shopId = data.shopId || "main_shop";
    const shopRef = db.collection("shops").doc(shopId);
    const saleRef = shopRef.collection("sales").doc(data.saleId);
    const todayStr = new Date().toISOString().split("T")[0];
    const timestamp = admin.firestore.FieldValue.serverTimestamp();
    await db.runTransaction(async (transaction) => {
        const saleSnap = await transaction.get(saleRef);
        if (!saleSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Sale not found.");
        }
        const saleData = saleSnap.data();
        if (saleData.status === "cancelled") {
            throw new functions.https.HttpsError("failed-precondition", "Sale is already cancelled.");
        }
        const items = (saleData.items || []);
        const cash = Number(saleData.cashAmount) || 0;
        const online = Number(saleData.onlineAmount) || 0;
        const total = Number(saleData.grandTotal) || 0;
        // 1. Read products
        const productsToRestore = [];
        for (const item of items) {
            const prodRef = shopRef.collection("products").doc(item.productId);
            const prodSnap = await transaction.get(prodRef);
            if (prodSnap.exists) {
                productsToRestore.push({ ref: prodRef, data: prodSnap.data(), item });
            }
        }
        const dailySummaryRef = shopRef.collection("daily_summaries").doc(todayStr);
        const dailySummarySnap = await transaction.get(dailySummaryRef);
        // 2. Restore stock
        for (const { ref: prodRef, data: prodData, item } of productsToRestore) {
            const currentAvailable = Number(prodData.availableQuantity) || 0;
            const currentSold = Number(prodData.totalSold) || 0;
            transaction.update(prodRef, {
                availableQuantity: Math.round((currentAvailable + item.quantity) * 100) / 100,
                totalSold: Math.max(0, Math.round((currentSold - item.quantity) * 100) / 100),
                updatedAt: timestamp,
            });
            // Record reversal movement
            const movementRef = shopRef.collection("stock_movements").doc();
            transaction.set(movementRef, {
                movementId: movementRef.id,
                productId: item.productId,
                productName: item.productName,
                movementType: "SALE_RETURN",
                quantity: item.quantity,
                unit: item.unit,
                referenceId: data.saleId,
                date: todayStr,
                notes: `Sale cancellation: ${data.reason}`,
                createdBy: auth.uid,
                createdAt: timestamp,
            });
        }
        // 3. Mark sale cancelled
        transaction.update(saleRef, {
            status: "cancelled",
            cancellationReason: data.reason,
            cancelledAt: timestamp,
            cancelledBy: auth.uid,
        });
        // 4. Reverse financial ledger
        const accountEntryRef = shopRef.collection("account_entries").doc();
        transaction.set(accountEntryRef, {
            entryId: accountEntryRef.id,
            date: todayStr,
            transactionType: "REFUND",
            referenceId: data.saleId,
            cashAmount: -cash,
            onlineAmount: -online,
            description: `Cancelled Sale #${saleData.invoiceNumber || data.saleId} - ${data.reason}`,
            status: "active",
            createdBy: auth.uid,
            createdAt: timestamp,
        });
        // 5. Update daily summary
        if (dailySummarySnap.exists) {
            const current = dailySummarySnap.data();
            transaction.update(dailySummaryRef, {
                cashSales: Math.max(0, (Number(current.cashSales) || 0) - cash),
                onlineSales: Math.max(0, (Number(current.onlineSales) || 0) - online),
                totalSales: Math.max(0, (Number(current.totalSales) || 0) - total),
                closingCashBalance: (Number(current.closingCashBalance) || 0) - cash,
                closingOnlineBalance: (Number(current.closingOnlineBalance) || 0) - online,
            });
        }
    });
    return { success: true, message: "Sale cancelled and stock restored successfully." };
});
//# sourceMappingURL=index.js.map