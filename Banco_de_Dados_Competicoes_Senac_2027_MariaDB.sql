-- ============================================================================
-- COMPETIÇÕES SENAC 2027 | DESENVOLVIMENTO DE SISTEMAS
-- Sistema de Gestão de Ingressos Gratuitos por Setor — O Grande Show
-- Módulo 1: modelagem, criação da base e dados de teste
-- Compatibilidade-alvo: MariaDB 10.5+
--
-- Uso seguro:
--   1. Execute em uma instância de desenvolvimento sem dados de produção.
--   2. Este script NÃO exclui banco, tabelas ou dados existentes.
--   3. Os INSERTs de teste são destinados a uma base nova; não execute a seção
--      de dados duas vezes no mesmo banco.
-- ============================================================================

CREATE DATABASE IF NOT EXISTS sistema_ingressos_grande_show
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE sistema_ingressos_grande_show;

-- -----------------------------------------------------------------------------
-- 1. TABELAS DE CADASTRO E ACESSO
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS perfis (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nome VARCHAR(30) NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT uq_perfis_nome UNIQUE (nome)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS usuarios (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  perfil_id BIGINT UNSIGNED NOT NULL,
  nome VARCHAR(120) NOT NULL,
  cpf CHAR(11) NOT NULL,
  email VARCHAR(255) NOT NULL,
  senha_hash VARCHAR(255) NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT uq_usuarios_cpf UNIQUE (cpf),
  CONSTRAINT uq_usuarios_email UNIQUE (email),
  CONSTRAINT ck_usuarios_cpf CHECK (cpf REGEXP '^[0-9]{11}$'),
  CONSTRAINT ck_usuarios_ativo CHECK (ativo IN (0, 1)),
  CONSTRAINT fk_usuarios_perfil
    FOREIGN KEY (perfil_id) REFERENCES perfis (id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 2. EVENTO, SETORES E CLIENTES
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS eventos (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nome VARCHAR(150) NOT NULL,
  data_evento DATETIME NOT NULL,
  capacidade_maxima INT UNSIGNED NOT NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT ck_eventos_capacidade CHECK (capacidade_maxima > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS setores (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  evento_id BIGINT UNSIGNED NOT NULL,
  nome VARCHAR(100) NOT NULL,
  capacidade INT UNSIGNED NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT uq_setores_evento_nome UNIQUE (evento_id, nome),
  CONSTRAINT ck_setores_capacidade CHECK (capacidade > 0),
  CONSTRAINT ck_setores_ativo CHECK (ativo IN (0, 1)),
  CONSTRAINT fk_setores_evento
    FOREIGN KEY (evento_id) REFERENCES eventos (id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS clientes (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nome VARCHAR(120) NOT NULL,
  cpf CHAR(11) NOT NULL,
  email VARCHAR(255) NOT NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT uq_clientes_cpf UNIQUE (cpf),
  CONSTRAINT ck_clientes_cpf CHECK (cpf REGEXP '^[0-9]{11}$')
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 3. OPERAÇÃO: RESERVAS, INGRESSOS, VALIDAÇÕES E AUDITORIA
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS reservas (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  cliente_id BIGINT UNSIGNED NOT NULL,
  setor_id BIGINT UNSIGNED NOT NULL,
  vendedor_id BIGINT UNSIGNED NOT NULL,
  criada_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_reservas_cliente (cliente_id),
  KEY idx_reservas_setor (setor_id),
  KEY idx_reservas_vendedor (vendedor_id),
  CONSTRAINT fk_reservas_cliente
    FOREIGN KEY (cliente_id) REFERENCES clientes (id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_reservas_setor
    FOREIGN KEY (setor_id) REFERENCES setores (id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_reservas_vendedor
    FOREIGN KEY (vendedor_id) REFERENCES usuarios (id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ingressos (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  reserva_id BIGINT UNSIGNED NOT NULL,
  codigo CHAR(8) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'EMITIDO',
  emitido_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  validado_em DATETIME NULL,
  PRIMARY KEY (id),
  CONSTRAINT uq_ingressos_codigo UNIQUE (codigo),
  KEY idx_ingressos_reserva_status (reserva_id, status),
  CONSTRAINT ck_ingressos_status
    CHECK (status IN ('EMITIDO', 'VALIDADO', 'CANCELADO')),
  CONSTRAINT ck_ingressos_data_validacao
    CHECK (
      (status = 'VALIDADO' AND validado_em IS NOT NULL)
      OR (status IN ('EMITIDO', 'CANCELADO') AND validado_em IS NULL)
    ),
  CONSTRAINT fk_ingressos_reserva
    FOREIGN KEY (reserva_id) REFERENCES reservas (id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS validacoes (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  ingresso_id BIGINT UNSIGNED NULL,
  codigo_informado CHAR(8) NOT NULL,
  validador_id BIGINT UNSIGNED NOT NULL,
  resultado VARCHAR(30) NOT NULL,
  motivo VARCHAR(255) NULL,
  tentativa_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_validacoes_ingresso (ingresso_id),
  KEY idx_validacoes_validador_data (validador_id, tentativa_em),
  CONSTRAINT ck_validacoes_resultado
    CHECK (
      resultado IN (
        'ACEITA',
        'RECUSADA_JA_VALIDADO',
        'RECUSADA_CANCELADO',
        'RECUSADA_INEXISTENTE'
      )
    ),
  CONSTRAINT ck_validacoes_ingresso_resultado
    CHECK (
      (resultado = 'RECUSADA_INEXISTENTE' AND ingresso_id IS NULL)
      OR (
        resultado IN ('ACEITA', 'RECUSADA_JA_VALIDADO', 'RECUSADA_CANCELADO')
        AND ingresso_id IS NOT NULL
      )
    ),
  CONSTRAINT fk_validacoes_ingresso
    FOREIGN KEY (ingresso_id) REFERENCES ingressos (id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_validacoes_validador
    FOREIGN KEY (validador_id) REFERENCES usuarios (id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS movimentacoes (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  usuario_id BIGINT UNSIGNED NOT NULL,
  reserva_id BIGINT UNSIGNED NULL,
  ingresso_id BIGINT UNSIGNED NULL,
  tipo VARCHAR(40) NOT NULL,
  descricao VARCHAR(255) NOT NULL,
  ocorrida_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_movimentacoes_usuario_data (usuario_id, ocorrida_em),
  KEY idx_movimentacoes_reserva_data (reserva_id, ocorrida_em),
  KEY idx_movimentacoes_ingresso_data (ingresso_id, ocorrida_em),
  CONSTRAINT ck_movimentacoes_tipo
    CHECK (
      tipo IN (
        'RESERVA_CRIADA',
        'INGRESSO_EMITIDO',
        'INGRESSO_CANCELADO',
        'INGRESSO_VALIDADO',
        'VALIDACAO_RECUSADA'
      )
    ),
  CONSTRAINT fk_movimentacoes_usuario
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_movimentacoes_reserva
    FOREIGN KEY (reserva_id) REFERENCES reservas (id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_movimentacoes_ingresso
    FOREIGN KEY (ingresso_id) REFERENCES ingressos (id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 4. VIEWS DE CONSULTA PARA OPERAÇÃO E DASHBOARD
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW vw_ocupacao_setores AS
SELECT
  e.id AS evento_id,
  e.nome AS evento_nome,
  s.id AS setor_id,
  s.nome AS setor_nome,
  s.capacidade,
  COALESCE(SUM(CASE
    WHEN i.status IN ('EMITIDO', 'VALIDADO') THEN 1
    ELSE 0
  END), 0) AS ingressos_ativos,
  COALESCE(SUM(CASE WHEN i.status = 'VALIDADO' THEN 1 ELSE 0 END), 0)
    AS ingressos_validados,
  COALESCE(SUM(CASE WHEN i.status = 'CANCELADO' THEN 1 ELSE 0 END), 0)
    AS ingressos_cancelados,
  s.capacidade - COALESCE(SUM(CASE
    WHEN i.status IN ('EMITIDO', 'VALIDADO') THEN 1
    ELSE 0
  END), 0) AS vagas_disponiveis,
  ROUND(
    COALESCE(SUM(CASE
      WHEN i.status IN ('EMITIDO', 'VALIDADO') THEN 1
      ELSE 0
    END), 0) / s.capacidade * 100,
    2
  ) AS percentual_ocupacao,
  CASE
    WHEN COALESCE(SUM(CASE
      WHEN i.status IN ('EMITIDO', 'VALIDADO') THEN 1
      ELSE 0
    END), 0) >= s.capacidade THEN 'ESGOTADO'
    WHEN COALESCE(SUM(CASE
      WHEN i.status IN ('EMITIDO', 'VALIDADO') THEN 1
      ELSE 0
    END), 0) / s.capacidade >= 0.80 THEN 'CRITICO'
    ELSE 'DISPONIVEL'
  END AS status_lotacao
FROM eventos e
JOIN setores s ON s.evento_id = e.id
LEFT JOIN reservas r ON r.setor_id = s.id
LEFT JOIN ingressos i ON i.reserva_id = r.id
GROUP BY e.id, e.nome, s.id, s.nome, s.capacidade;

CREATE OR REPLACE VIEW vw_resumo_eventos AS
SELECT
  e.id AS evento_id,
  e.nome AS evento_nome,
  e.data_evento,
  e.capacidade_maxima,
  COALESCE(SUM(o.ingressos_ativos), 0) AS ingressos_ativos,
  COALESCE(SUM(o.ingressos_validados), 0) AS ingressos_validados,
  COALESCE(SUM(o.ingressos_cancelados), 0) AS ingressos_cancelados,
  COALESCE(SUM(CASE WHEN o.status_lotacao = 'ESGOTADO' THEN 1 ELSE 0 END), 0)
    AS setores_esgotados,
  COALESCE(SUM(CASE WHEN o.status_lotacao = 'CRITICO' THEN 1 ELSE 0 END), 0)
    AS setores_criticos
FROM eventos e
LEFT JOIN vw_ocupacao_setores o ON o.evento_id = e.id
GROUP BY e.id, e.nome, e.data_evento, e.capacidade_maxima;

-- -----------------------------------------------------------------------------
-- 5. DADOS DE TESTE PADRONIZADOS
--
-- Senha de todas as contas de teste: password
-- O valor armazenado é um hash bcrypt de teste; substitua por hashes próprios
-- antes de publicar a aplicação.
-- -----------------------------------------------------------------------------

INSERT INTO perfis (id, nome) VALUES
  (1, 'Administrador'),
  (2, 'Vendedor'),
  (3, 'Validador');

INSERT INTO usuarios
  (id, perfil_id, nome, cpf, email, senha_hash, ativo, criado_em)
VALUES
  (1, 1, 'Administrador do Sistema', '52998224725', 'admin@grande.show',
   '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 1,
   '2027-08-01 08:00:00'),
  (2, 2, 'Ana Ribeiro', '11144477735', 'ana.vendedora@grande.show',
   '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 1,
   '2027-08-01 08:05:00'),
  (3, 2, 'Carlos Souza', '12345678909', 'carlos.vendedor@grande.show',
   '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 1,
   '2027-08-01 08:10:00'),
  (4, 3, 'Beatriz Lima', '93541134780', 'beatriz.validadora@grande.show',
   '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 1,
   '2027-08-01 08:15:00'),
  (5, 3, 'Diego Alves', '71460238001', 'diego.validador@grande.show',
   '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 1,
   '2027-08-01 08:20:00');

INSERT INTO eventos (id, nome, data_evento, capacidade_maxima, criado_em) VALUES
  (1, 'O Grande Show', '2027-10-15 20:00:00', 5000, '2027-08-01 09:00:00');

INSERT INTO setores (id, evento_id, nome, capacidade, ativo, criado_em) VALUES
  (1, 1, 'Público Geral', 3000, 1, '2027-08-01 09:05:00'),
  (2, 1, 'VIP', 1000, 1, '2027-08-01 09:05:00'),
  (3, 1, 'Imprensa', 1000, 1, '2027-08-01 09:05:00');

INSERT INTO clientes (id, nome, cpf, email, criado_em) VALUES
  (1, 'Joana Martins', '39053344705', 'joana.martins@email.teste',
   '2027-09-01 10:00:00'),
  (2, 'Rafael Nunes', '98765432100', 'rafael.nunes@email.teste',
   '2027-09-01 10:10:00'),
  (3, 'Larissa Costa', '28540967138', 'larissa.costa@email.teste',
   '2027-09-01 10:20:00'),
  (4, 'Pedro Ferreira', '43178265009', 'pedro.ferreira@email.teste',
   '2027-09-01 10:30:00'),
  (5, 'Marina Lopes', '60231948576', 'marina.lopes@email.teste',
   '2027-09-01 10:40:00');

INSERT INTO reservas (id, cliente_id, setor_id, vendedor_id, criada_em) VALUES
  (1, 1, 1, 2, '2027-09-01 11:00:00'),
  (2, 2, 2, 2, '2027-09-01 11:10:00'),
  (3, 3, 1, 3, '2027-09-01 11:20:00'),
  (4, 4, 3, 3, '2027-09-01 11:30:00'),
  (5, 5, 2, 2, '2027-09-01 11:40:00');

INSERT INTO ingressos
  (id, reserva_id, codigo, status, emitido_em, validado_em)
VALUES
  (1, 1, 'GS27A001', 'VALIDADO', '2027-09-01 11:00:00', '2027-10-15 19:00:00'),
  (2, 1, 'GS27A002', 'EMITIDO',  '2027-09-01 11:00:00', NULL),
  (3, 2, 'GS27B001', 'EMITIDO',  '2027-09-01 11:10:00', NULL),
  (4, 2, 'GS27B002', 'EMITIDO',  '2027-09-01 11:10:00', NULL),
  (5, 3, 'GS27C001', 'VALIDADO', '2027-09-01 11:20:00', '2027-10-15 19:05:00'),
  (6, 3, 'GS27C002', 'CANCELADO','2027-09-01 11:20:00', NULL),
  (7, 4, 'GS27D001', 'CANCELADO','2027-09-01 11:30:00', NULL),
  (8, 5, 'GS27E001', 'VALIDADO', '2027-09-01 11:40:00', '2027-10-15 19:10:00'),
  (9, 5, 'GS27E002', 'EMITIDO',  '2027-09-01 11:40:00', NULL);

INSERT INTO validacoes
  (id, ingresso_id, codigo_informado, validador_id, resultado, motivo, tentativa_em)
VALUES
  (1, 1,    'GS27A001', 4, 'ACEITA', NULL, '2027-10-15 19:00:00'),
  (2, 5,    'GS27C001', 4, 'ACEITA', NULL, '2027-10-15 19:05:00'),
  (3, 1,    'GS27A001', 4, 'RECUSADA_JA_VALIDADO', 'Ingresso já utilizado.',
   '2027-10-15 19:01:00'),
  (4, 7,    'GS27D001', 5, 'RECUSADA_CANCELADO', 'Ingresso cancelado.',
   '2027-10-15 19:02:00'),
  (5, NULL, 'GS27ZZ99', 5, 'RECUSADA_INEXISTENTE', 'Código não localizado.',
   '2027-10-15 19:03:00');

INSERT INTO movimentacoes
  (id, usuario_id, reserva_id, ingresso_id, tipo, descricao, ocorrida_em)
VALUES
  (1,  2, 1, NULL, 'RESERVA_CRIADA', 'Reserva criada para Joana Martins no setor Público Geral.',
   '2027-09-01 11:00:00'),
  (2,  2, 1, 1, 'INGRESSO_EMITIDO', 'Ingresso GS27A001 emitido.', '2027-09-01 11:00:00'),
  (3,  2, 1, 2, 'INGRESSO_EMITIDO', 'Ingresso GS27A002 emitido.', '2027-09-01 11:00:00'),
  (4,  2, 2, NULL, 'RESERVA_CRIADA', 'Reserva criada para Rafael Nunes no setor VIP.',
   '2027-09-01 11:10:00'),
  (5,  3, 3, NULL, 'RESERVA_CRIADA', 'Reserva criada para Larissa Costa no setor Público Geral.',
   '2027-09-01 11:20:00'),
  (6,  1, 3, 6, 'INGRESSO_CANCELADO', 'Ingresso GS27C002 cancelado.', '2027-09-02 09:00:00'),
  (7,  3, 4, NULL, 'RESERVA_CRIADA', 'Reserva criada para Pedro Ferreira no setor Imprensa.',
   '2027-09-01 11:30:00'),
  (8,  1, 4, 7, 'INGRESSO_CANCELADO', 'Ingresso GS27D001 cancelado.', '2027-09-02 09:05:00'),
  (9,  2, 5, NULL, 'RESERVA_CRIADA', 'Reserva criada para Marina Lopes no setor VIP.',
   '2027-09-01 11:40:00'),
  (10, 4, 1, 1, 'INGRESSO_VALIDADO', 'Ingresso GS27A001 validado na entrada.',
   '2027-10-15 19:00:00'),
  (11, 5, 4, 7, 'VALIDACAO_RECUSADA', 'Tentativa com ingresso cancelado.',
   '2027-10-15 19:02:00'),
  (12, 5, NULL, NULL, 'VALIDACAO_RECUSADA', 'Tentativa com código inexistente GS27ZZ99.',
   '2027-10-15 19:03:00'),
  (13, 4, 3, 5, 'INGRESSO_VALIDADO', 'Ingresso GS27C001 validado na entrada.',
   '2027-10-15 19:05:00'),
  (14, 4, 5, 8, 'INGRESSO_VALIDADO', 'Ingresso GS27E001 validado na entrada.',
   '2027-10-15 19:10:00');

-- -----------------------------------------------------------------------------
-- 6. CONSULTAS DE CONFERÊNCIA
-- -----------------------------------------------------------------------------

-- Deve retornar 3 perfis, 5 usuários, 1 evento, 3 setores e pelo menos 5
-- registros nas demais tabelas operacionais.
SELECT 'perfis' AS tabela, COUNT(*) AS quantidade FROM perfis
UNION ALL SELECT 'usuarios', COUNT(*) FROM usuarios
UNION ALL SELECT 'eventos', COUNT(*) FROM eventos
UNION ALL SELECT 'setores', COUNT(*) FROM setores
UNION ALL SELECT 'clientes', COUNT(*) FROM clientes
UNION ALL SELECT 'reservas', COUNT(*) FROM reservas
UNION ALL SELECT 'ingressos', COUNT(*) FROM ingressos
UNION ALL SELECT 'validacoes', COUNT(*) FROM validacoes
UNION ALL SELECT 'movimentacoes', COUNT(*) FROM movimentacoes;

-- Ocupação por setor; ingressos CANCELADOS não consomem vagas.
SELECT *
FROM vw_ocupacao_setores
ORDER BY setor_id;

-- Resumo para o dashboard administrativo.
SELECT *
FROM vw_resumo_eventos;

-- Histórico de validação, inclusive as recusadas.
SELECT
  v.id,
  v.codigo_informado,
  v.resultado,
  v.motivo,
  v.tentativa_em,
  u.nome AS validador
FROM validacoes v
JOIN usuarios u ON u.id = v.validador_id
ORDER BY v.tentativa_em;

-- Testes negativos sugeridos: executar individualmente e esperar erro.
-- 1) Código duplicado:
-- INSERT INTO ingressos (reserva_id, codigo, status)
-- VALUES (1, 'GS27A001', 'EMITIDO');
--
-- 2) Setor com capacidade inválida:
-- INSERT INTO setores (evento_id, nome, capacidade) VALUES (1, 'Teste', 0);
--
-- 3) Validação inexistente vinculada a ingresso (viola a regra de domínio):
-- INSERT INTO validacoes (ingresso_id, codigo_informado, validador_id, resultado)
-- VALUES (1, 'GS27A001', 4, 'RECUSADA_INEXISTENTE');
