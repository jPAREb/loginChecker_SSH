#!/bin/bash

# Nom de la base de dades
DB_NAME="ips.db"

# Comandes SQL per crear una taula
SQL_COMMANDS="
CREATE TABLE IF NOT EXISTS connections (
    ip TEXT PRIMARY KEY,
    pais TEXT,
    count INTEGER,
    reported INTEGER NOT NULL DEFAULT 0,
    date TEXT
);

# Crear la base de dades i la taula
sqlite3 $DB_NAME <<EOF
$SQL_COMMANDS
EOF

echo "database created"
