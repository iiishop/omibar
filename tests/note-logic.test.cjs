const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const logic = vm.createContext({ Date, Math, JSON });
vm.runInContext(fs.readFileSync('modules/note/NoteLogic.js', 'utf8'), logic);
const markdown = vm.createContext({});
vm.runInContext(fs.readFileSync('modules/note/MarkdownDocument.js', 'utf8'), markdown);
const plain = value => JSON.parse(JSON.stringify(value));

test('notes roundtrip, reject invalid versions, duplicate IDs and malformed records', () => {
    const note = logic.createNote(1000, false);
    assert.deepEqual(plain(logic.decode(JSON.stringify({ version: 1, notes: [note] }))), [plain(note)]);
    for (const value of [{version: 2, notes: []}, {version: 1, notes: [note, note]},
        {version: 1, notes: [{...note, dueAt: 'tomorrow'}]}, {version: 1, notes: [{}]}])
        assert.throws(() => logic.decode(JSON.stringify(value)));
});

test('only active todo notes participate in counts and due alerts', () => {
    const now = new Date(2026, 8, 6, 14, 30).getTime();
    const note = {...logic.createNote(now - 1000, true), dueAt: now};
    assert.equal(logic.isDue(note, now), true);
    assert.equal(logic.needsAlert(note, now), true);
    for (const changes of [{todo: false}, {completedAt: now}, {archived: true},
        {deletedAt: now}, {dueAt: null}, {snoozedUntil: now + 600000}])
        assert.equal(logic.needsAlert({...note, ...changes}, now), false);
    assert.equal(logic.needsAlert({...note, lastAlertedAt: now}, now + 60000), false);
    assert.equal(logic.needsAlert({...note, lastAlertedAt: now, snoozedUntil: now + 600000}, now + 600000), true);
    const summary = logic.summarize([note, {...note, todo: false}], now);
    assert.equal(summary.todos['2026-09-06'], 1);
    assert.equal(summary.overdue['2026-09-06'], 1);
});

test('shelf excludes completed, archived and deleted; created order survives edits', () => {
    const notes = [logic.createNote(100, false), logic.createNote(200, false)];
    notes[0].updatedAt = 300;
    assert.deepEqual(plain(logic.shelfNotes(notes).map(n => n.createdAt)), [200, 100]);
    notes[0].archived = true;
    notes[1].deletedAt = 400;
    assert.equal(logic.shelfNotes(notes).length, 0);
});

test('local date entry rejects rollover, invalid time and DST gaps', () => {
    assert.equal(logic.parseDue('2026-02-30', '14:30'), null);
    assert.equal(logic.parseDue('2026-09-06', '24:30'), null);
    const value = logic.parseDue('2026-09-06', '14:30');
    assert.equal(logic.dateKey(value), '2026-09-06');
    assert.equal(new Date(value).getHours(), 14);
});

test('markdown blocks preserve source exactly, including fences, tables and quotes', () => {
    for (const source of ['', '# Title\n\nParagraph\nnext\n', '```js\na()\n\n```\nend',
        '~~~~js\n```\n~~~~\n', '| A | B |\n| --- | --- |\n| x | y |\n\nend',
        '> first\n> next\n\n- [ ] item\n- second', '    indented\n    code\n']) {
        const blocks = markdown.blocks(source);
        assert.equal(blocks.map(b => b.text).join(''), source);
        for (const block of blocks)
            assert.equal(source.slice(block.start, block.end), block.text);
    }
    assert.equal(markdown.blocks('```js\na\nb\n```').length, 1);
    assert.equal(markdown.blocks('> a\n> b\n').length, 1);
    assert.equal(markdown.blocks('| a |\n| --- |\n| b |').length, 1);
});
