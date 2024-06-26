#!/bin/bash

# Nom de la base de dades
DB_NAME="ips.db"

# Comandes SQL per crear una taula
SQL_COMMANDS="
CREATE TABLE IF NOT EXISTS connexions (
    ip TEXT PRIMARY KEY,
    pais TEXT,
    count INTEGER
);

# Crear la base de dades i la taula
sqlite3 $DB_NAME <<EOF
$SQL_COMMANDS
EOF

echo "database created"
