// Keep exact source spans; Qt remains responsible for Markdown rendering.
/** @param {string} source @returns {{start: number, end: number, text: string}[]} */
function blocks(source) {
    const lines = source.match(/[^\n]*\n|[^\n]+$/g) || [''];
    const result = [];
    let offset = 0;
    for (let i = 0; i < lines.length;) {
        const start = i;
        const fence = lines[i].match(/^ {0,3}(`{3,}|~{3,})/);
        const table = i + 1 < lines.length && lines[i].includes('|')
            && /^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)*\|?\s*$/.test(lines[i + 1]);
        if (fence) {
            const close = new RegExp('^ {0,3}' + fence[1][0] + '{' + fence[1].length + ',}\\s*$');
            ++i;
            while (i < lines.length && !close.test(lines[i])) ++i;
            if (i < lines.length) ++i;
        } else if (table) {
            i += 2;
            while (i < lines.length && lines[i].includes('|') && lines[i].trim()) ++i;
        } else if (/^\s*>/.test(lines[i])) {
            ++i;
            while (i < lines.length && /^\s*>/.test(lines[i])) ++i;
        } else if (/^( {4}|\t)/.test(lines[i])) {
            ++i;
            while (i < lines.length && /^( {4}|\t)/.test(lines[i])) ++i;
        } else if (i + 1 < lines.length && lines[i].trim() && /^\s*(={3,}|-{3,})\s*$/.test(lines[i + 1])) {
            i += 2;
        } else {
            ++i;
        }
        const text = lines.slice(start, i).join('');
        result.push({ start: offset, end: offset + text.length, text });
        offset += text.length;
    }
    return result;
}
