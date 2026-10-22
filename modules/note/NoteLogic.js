// Pure note contracts shared by persistence, reminders and views.
/**
 * @typedef {Object} Note
 * @property {string} id
 * @property {string} title
 * @property {string} body
 * @property {number} createdAt
 * @property {number} updatedAt
 * @property {boolean} todo
 * @property {number|null} dueAt
 * @property {number|null} completedAt
 * @property {number|null} snoozedUntil
 * @property {number|null} lastAlertedAt
 * @property {boolean} pinned
 * @property {boolean} archived
 * @property {number|null} deletedAt
 */
const minuteMs = 60000;

/** @param {number} now @param {boolean} todo @returns {Note} */
function createNote(now, todo) {
    const id = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
        const value = Math.floor(Math.random() * 16);
        return (c === 'x' ? value : (value & 3) | 8).toString(16);
    });
    return { id, title: '', body: '', createdAt: now, updatedAt: now,
        todo, dueAt: null, completedAt: null, snoozedUntil: null,
        lastAlertedAt: null, pinned: false, archived: false, deletedAt: null };
}

/** @param {string} text @returns {Note[]} Validated version 1 records. */
function decode(text) {
    const data = JSON.parse(text);
    if (data.version !== 1 || !Array.isArray(data.notes))
        throw new Error('Unsupported notes schema');
    const ids = new Set();
    for (const note of data.notes) {
        if (!note || typeof note.id !== 'string' || !note.id || ids.has(note.id)
            || !['title', 'body'].every(key => typeof note[key] === 'string')
            || !['todo', 'pinned', 'archived'].every(key => typeof note[key] === 'boolean')
            || !['createdAt', 'updatedAt'].every(key => Number.isFinite(note[key]))
            || !['dueAt', 'completedAt', 'snoozedUntil', 'lastAlertedAt'].every(key =>
                note[key] === null || Number.isFinite(note[key]))
            || !(note.deletedAt === undefined || note.deletedAt === null || Number.isFinite(note.deletedAt)))
            throw new Error('Invalid note record or duplicate ID');
        ids.add(note.id);
        // Version 1 records from before soft deletion have no deletedAt field.
        if (note.deletedAt === undefined) note.deletedAt = null;
    }
    return data.notes;
}

/** @param {number} timestamp @returns {string} Local calendar date. */
function dateKey(timestamp) {
    const date = new Date(timestamp);
    return date.getFullYear() + '-' + String(date.getMonth() + 1).padStart(2, '0')
        + '-' + String(date.getDate()).padStart(2, '0');
}

/** @param {string} day @param {string} time @returns {number|null} Null rejects invalid local input. */
function parseDue(day, time) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(day) || !/^\d{2}:\d{2}$/.test(time)) return null;
    const [year, month, date] = day.split('-').map(Number);
    const [hour, minute] = time.split(':').map(Number);
    const value = new Date(year, month - 1, date, hour, minute);
    if (value.getFullYear() !== year || value.getMonth() !== month - 1
        || value.getDate() !== date || value.getHours() !== hour || value.getMinutes() !== minute)
        return null;
    return value.getTime();
}

/** @param {Note} note @returns {string} Explicit title or the first nonempty source line. */
function title(note) {
    return note.title.trim() || note.body.split('\n').find(line => line.trim())?.replace(/^\s*[#>*-]+\s*/, '').trim() || '';
}

/** @param {Note} note @returns {boolean} Whether a note participates in the calendar. */
function activeTodo(note) {
    return note.todo && note.completedAt === null && !note.archived && note.deletedAt === null
        && note.dueAt !== null;
}

/** @param {Note} note @param {number} now @returns {boolean} */
function isDue(note, now) {
    return activeTodo(note) && Math.max(note.dueAt, note.snoozedUntil ?? 0) <= now;
}

/** @param {Note} note @param {number} now @returns {boolean} Whether a new alert is owed. */
function needsAlert(note, now) {
    return isDue(note, now) && (note.lastAlertedAt === null
        || note.lastAlertedAt < Math.max(note.dueAt, note.snoozedUntil ?? 0));
}

/** @param {Note[]} notes @param {number} now @returns {{todos: Object<string, number>, overdue: Object<string, number>}} */
function summarize(notes, now) {
    const todos = {}, overdue = {};
    for (const note of notes.filter(activeTodo)) {
        const key = dateKey(note.dueAt);
        todos[key] = (todos[key] ?? 0) + 1;
        if (note.dueAt <= now) overdue[key] = (overdue[key] ?? 0) + 1;
    }
    return { todos, overdue };
}

/** @param {Note[]} notes @returns {Note[]} Eligible notes, newest first. */
function shelfNotes(notes) {
    return notes.filter(note => !note.archived && note.deletedAt === null
        && !(note.todo && note.completedAt !== null)).sort((a, b) => b.createdAt - a.createdAt);
}

/** @param {Note[]} notes @param {string} query @param {string} filter @param {string} day @param {number} now @returns {Note[]} */
function filterNotes(notes, query, filter, day, now) {
    const search = query.trim().toLocaleLowerCase();
    const score = note => title(note).toLocaleLowerCase().includes(search) ? 0 : 1;
    return notes.filter(note => {
        if (filter === 'trash' ? note.deletedAt === null : note.deletedAt !== null) return false;
        if (filter === 'archived' ? !note.archived : filter !== 'trash' && note.archived) return false;
        if (search && !(note.title + '\n' + note.body).toLocaleLowerCase().includes(search)) return false;
        if (day && !(activeTodo(note) && dateKey(note.dueAt) === day)) return false;
        if (filter === 'todo') return note.todo && note.completedAt === null;
        if (filter === 'today') return activeTodo(note) && dateKey(note.dueAt) === dateKey(now);
        if (filter === 'completed') return note.todo && note.completedAt !== null;
        return true;
    }).sort((a, b) => (search ? score(a) - score(b) : 0)
        || Number(b.pinned) - Number(a.pinned) || a.createdAt - b.createdAt);
}
